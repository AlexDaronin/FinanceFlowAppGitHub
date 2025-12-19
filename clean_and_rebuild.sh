#!/bin/bash

echo "🧹 Очистка кэша Xcode..."

# Очистка DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/FinanceFlow-*
echo "✅ DerivedData очищен"

# Очистка кэша Xcode
rm -rf ~/Library/Caches/com.apple.dt.Xcode
echo "✅ Кэш Xcode очищен"

# Очистка модулей Swift
find . -name "*.swiftmodule" -delete 2>/dev/null
find . -name "*.swiftdoc" -delete 2>/dev/null
echo "✅ Swift модули очищены"

# Очистка build папки в проекте
rm -rf build/
echo "✅ Build папка очищена"

echo ""
echo "✨ Очистка завершена!"
echo ""
echo "📝 Следующие шаги:"
echo "1. Закройте Xcode полностью (⌘Q)"
echo "2. Откройте проект заново"
echo "3. Дождитесь завершения индексации (прогресс-бар вверху)"
echo "4. Выполните Product → Clean Build Folder (⇧⌘K)"
echo "5. Выполните Product → Build (⌘B)"
echo "6. Запустите приложение (⌘R)"
echo ""




