#!/usr/bin/env python3
"""Read the two official feeds outside Supabase, then publish only successful sources."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone, timedelta
from html import unescape
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import sys
from urllib.parse import urljoin, urlsplit, urlunsplit
from urllib.request import Request, urlopen
from urllib.error import HTTPError
from getpass import getpass

SOURCES = [
    {'id':'university','name':'Üniversite','url':'https://www.bingol.edu.tr/buproject/HaberDuyuruEtkinlik.aspx?dil=tr&tip=0','parser':'grid'},
    {'id':'student_affairs','name':'Öğrenci İşleri','url':'https://oidb.bingol.edu.tr/duyurular/','parser':'cards'},
]
DEFAULT_ENDPOINT = 'https://mnrmromfbffzajncvzyd.supabase.co/functions/v1/official-news'
MONTHS = ['ocak','şubat','mart','nisan','mayıs','haziran','temmuz','ağustos','eylül','ekim','kasım','aralık']


def plain(text):
    return ' '.join(unescape(re.sub(r'<[^>]*>', ' ', text)).split())


def date_value(text):
    text=plain(text).replace('İ','i').replace('I','ı').lower()
    m=re.search(r'\b(\d{1,2})[./](\d{1,2})[./](20\d{2})\b',text)
    if m:
        day,month,year=map(int,m.groups())
    else:
        m=re.search(r'\b(\d{1,2})\s+([a-zçğıöşü]+)\s+(20\d{2})\b',text)
        if not m or m[2] not in MONTHS:return None
        day,month,year=int(m[1]),MONTHS.index(m[2])+1,int(m[3])
    try:return datetime(year,month,day,tzinfo=timezone(timedelta(hours=3))).isoformat()
    except ValueError:return None


def official_url(link,base):
    u=urlsplit(urljoin(base,unescape(link)))
    if u.scheme not in ('http','https') or u.username or u.password or u.port or not (u.hostname=='bingol.edu.tr' or (u.hostname or '').endswith('.bingol.edu.tr')):return None
    return urlunsplit(('https',u.netloc,u.path.rstrip('/'),u.query,''))


def href(attrs):
    m=re.search(r'''(?:^|\s)href\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))''',attrs,re.I)
    return next((g for g in m.groups() if g is not None),None) if m else None


def parse_items(text,source):
    items={}
    def add(link,title,date):
        url=official_url(link,source['url']);title=plain(title)
        if url and 4<=len(title)<=600:items.setdefault(url,{'title':title,'url':url,'category':source['name'],'source':source['id'],'published_at':date_value(date)})
    if source['parser']=='grid':
        for row in re.findall(r'''<tr\b[^>]*\bid\s*=\s*["'][^"']*DXDataRow\d+["'][^>]*>([\s\S]*?)</tr>''',text,re.I):
            a=re.search(r'<a\b([^>]*)>([\s\S]*?)</a>',row,re.I);cells=re.findall(r'<td\b[^>]*>([\s\S]*?)</td>',row,re.I)
            if a and len(cells)>=2 and href(a[1]):add(href(a[1]),a[2],cells[-1])
    else:
        for attrs,content in re.findall(r'<a\b([^>]*)>([\s\S]*?)</a>',text,re.I):
            title=re.search(r'''<h[234]\b[^>]*class\s*=\s*["'][^"']*media_w-heading[^"']*["'][^>]*>([\s\S]*?)</h[234]>''',content,re.I)
            date=re.search(r'<p\b[^>]*>([\s\S]*?)</p>',content,re.I)
            if title and href(attrs):add(href(attrs),title[1],date[1] if date else '')
    return list(items.values())[:60]


def collect(source):
    try:
        req=Request(source['url'],headers={'User-Agent':'Mozilla/5.0','Accept':'text/html','Accept-Language':'tr-TR,tr;q=0.9'})
        with urlopen(req,timeout=25) as r:
            if not official_url(r.url,source['url']):raise ValueError('Unexpected redirect')
            if r.status!=200:raise ValueError('Source HTTP '+str(r.status))
            if 'text/html' not in r.headers.get('Content-Type','').lower():raise ValueError('Unexpected content type')
            raw=r.read(3_000_001)
            if len(raw)>3_000_000:raise ValueError('Source response too large')
            text=raw.decode(r.headers.get_content_charset() or 'utf-8',errors='replace')
        items=parse_items(text,source)
        if not items:raise ValueError('No announcement rows found')
        return {'id':source['id'],'items':items},None
    except Exception as e:return None,source['id']+': '+str(e)[:240]


class ArticleContent(HTMLParser):
    """Capture only the announcement body, excluding navigation and galleries."""
    def __init__(self, url):
        super().__init__(convert_charrefs=True)
        self.url=url;self.depth=0;self.active=0;self.skip=0
        self.parts=[];self.links=[];self.current=None;self.images=0
    def handle_starttag(self,tag,attrs):
        a=dict(attrs)
        if tag=='div':
            self.depth+=1
            if not self.active and set(a.get('class','').split()) & {'sade','sayfa-icerik'}:self.active=self.depth
        if not self.active:return
        if tag in {'script','style','noscript'}:self.skip+=1
        if self.skip:return
        if tag in {'p','br','li','h2','h3','h4','tr'}:self.parts.append('\n')
        if tag=='img':self.images+=1
        if tag=='a':
            url=official_url(a.get('href',''),self.url)
            self.current={'url':url,'label':[]} if url and a.get('href') and not a['href'].startswith('#') else None
    def handle_endtag(self,tag):
        if self.active:
            if tag in {'script','style','noscript'}:self.skip=max(0,self.skip-1)
            elif not self.skip:
                if tag in {'p','li','h2','h3','h4','tr'}:self.parts.append('\n')
                if tag=='a' and self.current:
                    label=' '.join(''.join(self.current['label']).split())[:140]
                    url=self.current['url']
                    if not any(l['url']==url for l in self.links):self.links.append({'url':url,'label':label or 'Resmî bağlantı'})
                    self.current=None
            if tag=='div' and self.depth==self.active:self.active=0
        if tag=='div':self.depth=max(0,self.depth-1)
    def handle_data(self,data):
        if self.active and not self.skip:
            self.parts.append(data)
            if self.current:self.current['label'].append(data)
    def result(self):
        text='\n\n'.join(' '.join(line.split()) for line in ''.join(self.parts).splitlines() if line.strip())
        # A short source excerpt. Full text and original attachments stay on the university page.
        words=text.split()
        if len(words)>180:text=' '.join(words[:180])+'…'
        if len(text)>1500:text=text[:1500].rsplit(' ',1)[0]+'…'
        return {'body':text,'links':self.links[:8],'content_kind':'source_excerpt','contains_images':self.images>0}


def fetch_article(url):
    req=Request(url,headers={'User-Agent':'Mozilla/5.0','Accept':'text/html','Accept-Language':'tr-TR,tr;q=0.9'})
    with urlopen(req,timeout=15) as r:
        final=official_url(r.url,url)
        if not final or 'text/html' not in r.headers.get('Content-Type','').lower():raise ValueError('No official article HTML')
        data=r.read(3_000_001)
        if len(data)>3_000_000:raise ValueError('Article too large')
        parser=ArticleContent(final);parser.feed(data.decode(r.headers.get_content_charset() or 'utf-8',errors='replace'))
        return parser.result()


def enrich(item):
    try:
        result=fetch_article(item['url'])
        # Some central university pages only refer to a unit's actual announcement.
        if len(result['body'])<100:
            target=next((l['url'] for l in result['links'] if 'duyuru' in urlsplit(l['url']).path and l['url']!=item['url']),None)
            if target:
                try:
                    detail=fetch_article(target)
                    if len(detail['body'])>len(result['body']):
                        detail['links']=([{'url':target,'label':'Birim duyurusu'}]+detail['links']+result['links'])[:8]
                        result=detail
                except Exception:pass
        return dict(item,**result)
    except Exception:
        return dict(item,body='',links=[],content_kind='unavailable',contains_images=False)


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--publish',action='store_true',help='Send successful sources to your cache')
    ap.add_argument('--output',type=Path,default=Path('news_preview.json'))
    args=ap.parse_args()
    with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(collect,SOURCES))
    sources=[r for r,error in results if r]
    for result,error in results:
        print(error if error else result['id']+': '+str(len(result['items']))+' items')
    if not sources:sys.exit('No sources succeeded. Existing stored news was not changed.')
    unique={item['url']:item for source in sources for item in source['items']}
    print('Reading announcement details:',len(unique),flush=True)
    with ThreadPoolExecutor(max_workers=6) as pool:
        enriched={item['url']:item for item in pool.map(enrich,unique.values())}
    for source in sources:source['items']=[enriched[item['url']] for item in source['items']]
    print('Details with text:',sum(bool(i.get('body')) for i in enriched.values()),'/',len(enriched),flush=True)
    payload={'action':'publish','sources':sources}
    args.output.write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Preview:',args.output.resolve())
    if not args.publish:return
    endpoint=os.environ.get('NEWS_PUBLISH_URL',DEFAULT_ENDPOINT).strip()
    u=urlsplit(endpoint)
    if u.scheme!='https' or not (u.hostname or '').endswith('.supabase.co') or u.username or u.password or u.port or u.path!='/functions/v1/official-news' or u.query or u.fragment:sys.exit('Invalid publish endpoint.')
    token=os.environ.get('NEWS_INGEST_TOKEN','').strip()
    if not token and sys.stdin.isatty():token=getpass('NEWS_INGEST_TOKEN (hidden): ').strip()
    if len(token)<32 or len(token)>512:sys.exit('Set NEWS_INGEST_TOKEN to the same secret as Supabase (32+ characters).')
    req=Request(endpoint,data=json.dumps(payload,ensure_ascii=False).encode(),headers={'Content-Type':'application/json','x-news-ingest-token':token},method='POST')
    try:
        with urlopen(req,timeout=25) as r:data=json.load(r)
        if data.get('ok') is not True:sys.exit('Publish failed. Check the function Test response.')
        print('PUBLISHED:',data.get('items'),'items. Sources:',', '.join(data.get('updated_sources',[])))
    except HTTPError as e:
        try:body=json.load(e);message=body.get('error') or body.get('message') or 'See Supabase logs'
        except Exception:message='See Supabase logs'
        sys.exit('Publish HTTP '+str(e.code)+': '+str(message))
    except Exception:sys.exit('Could not connect to Supabase. Existing cache was not cleared.')


if __name__=='__main__':main()
