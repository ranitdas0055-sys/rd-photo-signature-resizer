# ফোন দিয়ে APK Build করার নিয়ম

1. GitHub Repository খুলুন।
2. Actions ট্যাবে যান।
3. Build Android APK workflow নির্বাচন করুন।
4. Run workflow চাপুন।
5. Build শেষ হলে workflow run খুলুন।
6. Artifacts থেকে rd-photo-signature-resizer-debug-apk ডাউনলোড করুন।
7. ZIP Extract করে APK ইনস্টল করুন।

প্রথমে ফোনের Settings থেকে এই APK ইনস্টলের অনুমতি দিতে হতে পারে।

নোট: এটি Debug APK। Play Store-এর জন্য পরে release signing এবং AAB তৈরি করতে হবে। AdMob-এর test ID ব্যবহার করা হয়েছে; প্রকাশের আগে নিজের ID বসাতে হবে।
