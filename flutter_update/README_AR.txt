فك المجلد flutter_update داخل مجلد مشروع Flutter
شغل الأوامر من جذر المشروع الذي يحتوي pubspec.yaml

python .\flutter_update\install_meals.py --apply
flutter pub add http
dart format lib/core/cafeteria_repository.dart lib/features/cafeteria_screen.dart
flutter analyze

أعد تشغيل التطبيق بعد التثبيت
يستبدل المثبت قسم CafeteriaScreen فقط ويحفظ نسخة من الملف قبل التعديل
المصدر الرسمي https://sks.bingol.edu.tr/yemek-listesi
تجلب GitHub القائمة كل 6 ساعات ويقرأ التطبيق data/meals.json من المستودع العام
لا يحتاج هذا القسم رمز نشر أو إعداد Supabase
