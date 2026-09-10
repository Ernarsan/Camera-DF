# Промт для AI-агента: разработка приложения AI Compose Camera (iOS, Swift/SwiftUI)

Ты — iOS-разработчик. Реализуй нативное iOS-приложение по техническому заданию ниже.
Создай все файлы строго по указанной структуре и контрактам. Используй XcodeGen
(`project.yml`) для генерации `.xcodeproj` — без ручного редактирования pbxproj.

## 1. Суть продукта

Камера-приложение, повторяющее логику AI-помощника композиции кадра:
- Live-анализ кадра через Vision framework, пока пользователь держит телефон
- Подсветка "значимого" объекта в кадре рамкой поверх видоискателя
- Рекомендация зума на основе того, какую долю кадра занимает объект
- Рекомендация фильтра/пресета на основе анализа сцены (яркость, цветовая температура)
- UI с overlay-подсказками, кнопкой принятия рекомендации зума, финальным захватом фото
  с применением подобранного фильтра

## 2. Стек

- Swift 5 / SwiftUI, минимальный таргет iOS 16.0
- AVFoundation — захват видео и фото (`AVCaptureSession`, `AVCaptureVideoDataOutput`, `AVCapturePhotoOutput`)
- Vision — `VNGenerateAttentionBasedSaliencyImageRequest` для поиска значимой области кадра
- CoreImage — анализ цвета (`CIAreaAverage`) и применение фильтров (`CITemperatureAndTint`, `CIColorControls`)
- Photos — сохранение снимка в галерею
- XcodeGen — генерация `.xcodeproj` из `project.yml` (воспроизводимо для CI)

## 3. Дерево файлов

```
AIComposeCamera/
├── project.yml                          # XcodeGen-спека: target, bundle id, Info.plist-ключи, deployment target
├── Sources/
│   ├── App/
│   │   └── AIComposeCameraApp.swift     # @main, точка входа, root — ContentView
│   ├── UI/
│   │   ├── ContentView.swift            # Главный экран: preview + overlay + controls
│   │   ├── CameraPreviewView.swift      # UIViewRepresentable, AVCaptureVideoPreviewLayer
│   │   ├── SaliencyBoxView.swift        # Рамка вокруг значимого объекта (конвертация координат Vision → SwiftUI)
│   │   └── SuggestionBubbleView.swift   # Текстовые подсказки: "AI анализирует...", рекомендация фильтра
│   ├── Camera/
│   │   └── CameraViewModel.swift        # ObservableObject: AVCaptureSession, делегаты, published-состояние
│   └── Vision/
│       ├── CompositionAnalyzer.swift    # Saliency-анализ → bounding box + рекомендованный zoom factor
│       ├── SceneFilterRecommender.swift # Анализ яркости/цвета → фильтр + текст-обоснование
│       ├── AlignmentGuide.swift         # NEW: точка-мишень композиции + наведение "подвинь телефон"
│       └── NightEnhancer.swift          # NEW: улучшение кадра при слабом освещении
```

## 4. Контракты между модулями

### CompositionAnalyzer

```swift
struct CompositionResult {
    let saliencyBox: CGRect?      // нормализованные координаты Vision (origin bottom-left, 0...1)
    let suggestedZoom: CGFloat?   // 1x / 2x / 4x / 6x
}

static func analyze(ciImage: CIImage, completion: @escaping (CompositionResult) -> Void)
```

Логика подбора зума по площади bounding box относительно кадра:
- < 5% кадра → 6x
- < 12% → 4x
- < 25% → 2x
- иначе → 1x

### SceneFilterRecommender

```swift
struct SceneRecommendation {
    let sceneDescription: String   // напр. "Яркий пейзаж на улице"
    let filterName: String         // напр. "Cool F160C"
    let reason: String             // текст-обоснование для UI-бабла
}

static func recommend(for image: CIImage, context: CIContext) -> SceneRecommendation
static func applyLastFilter(to image: UIImage) -> UIImage
```

Логика: считать среднюю яркость через `CIAreaAverage` + соотношение каналов R/B.
Четыре сценария → каждому соответствует свой `CIFilter`:
1. Ярко + холодные тона (B > R) → `CITemperatureAndTint`, сдвиг в холод
2. Ярко + тёплые тона (R > B) → `CITemperatureAndTint`, сдвиг в тепло
3. Низкая яркость → `CIColorControls`, +контраст +экспозиция
4. Нейтральная сцена → без фильтра

### AlignmentGuide (новый режим — наведение на точку композиции)

Референс: AI фиксирует на экране целевую точку (композиционный узел, например пересечение
линий трети над центром кадра), находит ключевую точку объекта (лицо человека) через Vision,
и в реальном времени подсказывает пользователю **физически подвинуть телефон**, пока объект
не совпадёт с целевой точкой — только тогда разрешается/подсвечивается съёмка.

```swift
struct AlignmentGuidance {
    let targetPoint: CGPoint            // нормализованная целевая точка (0...1), фиксирована на кадр
    let currentSubjectPoint: CGPoint?   // текущая позиция лица/объекта, нормализованная
    let distance: CGFloat               // расстояние currentSubjectPoint → targetPoint
    let isAligned: Bool                 // distance < порога (напр. 0.04 от диагонали кадра)
    let instruction: String             // "Move your phone to align the composition point" /
                                         // "Perfect Composition" при isAligned == true
}

static func evaluate(ciImage: CIImage, completion: @escaping (AlignmentGuidance) -> Void)
```

Логика:
- Детекция лица — `VNDetectFaceRectanglesRequest` (fallback на `VNDetectHumanRectanglesRequest`,
  если лицо не найдено — вести по центру силуэта человека)
- `targetPoint` задаётся пресетом сцены (для портрета на фоне пейзажа — верхняя треть кадра,
  чуть выше центра по X)
- Пока `isAligned == false` — рамка вокруг preview окрашена радужным градиентом (анимация),
  на экране рисуется белый кружок-мишень (`targetPoint`) поверх видоискателя
- Когда `isAligned == true` — рамка становится однотонной (акцентный цвет), текст меняется на
  "Perfect Composition", кнопка затвора получает лёгкий пульс/подсветку

### NightEnhancer (улучшение при слабом освещении)

Референс-видео: итоговый кадр заметно ярче и контрастнее, чем в живом видоискателе при съёмке
ночью. Это НЕ настоящий multi-frame night mode (стекинг нескольких экспозиций для шумоподавления
— отдельная большая задача уровня Apple Deep Fusion/Night mode), а лёгкая имитация через CoreImage
сразу после захвата.

```swift
struct NightEnhanceResult {
    let isLowLight: Bool          // сцена определена как тёмная (средняя яркость < порога)
    let enhancedImage: UIImage?   // результат после обработки
}

static func enhanceIfNeeded(_ image: UIImage) -> NightEnhanceResult
```

Логика: если средняя яркость кадра (используем ту же метрику, что и в `SceneFilterRecommender`)
ниже порога — применить цепочку `CIExposureAdjust` (+EV) → `CIColorControls` (+контраст,
лёгкое +насыщение) → `CINoiseReduction`. Пометить в `sceneDescription` как "Съёмка в тёмное
время суток" и не предлагать дневные фильтры одновременно.

## 5. Published-состояние CameraViewModel

```swift
@Published var isAnalyzing: Bool           // показывать бабл "AI анализирует, держите камеру неподвижно"
@Published var suggestedBox: CGRect?       // рисовать SaliencyBoxView
@Published var suggestedZoom: CGFloat?     // показывать кнопку "Приблизить до Nx"
@Published var sceneDescription: String
@Published var filterName: String
@Published var filterReason: String
@Published var capturedImage: UIImage?
@Published var currentZoomFactor: CGFloat

// AlignmentGuide
@Published var targetCompositionPoint: CGPoint?   // рисовать кружок-мишень
@Published var currentSubjectPoint: CGPoint?
@Published var isAligned: Bool
@Published var alignmentInstruction: String        // текст бабла режима наведения

// NightEnhancer
@Published var isLowLight: Bool
```

## 6. Поток экрана

1. Открытие камеры → сразу live-preview на весь экран
2. Раз в ~0.6 сек текущий кадр отправляется в `CompositionAnalyzer` (обязательный throttling,
   не гонять Vision на каждый фрейм — перегрев и просадка FPS)
3. Пока идёт анализ — бабл "AI is analyzing / Please hold still"
4. Как только есть результат — рамка вокруг объекта (`SaliencyBoxView`) + кнопка "Приблизить до Nx"
5. Параллельно (независимо от saliency) — рекомендация фильтра с текстом-обоснованием
6. Пользователь либо жмёт кнопку зума (`device.videoZoomFactor`), либо сразу жмёт затвор
7. При захвате — к финальному фото применяется последний рекомендованный `CIFilter`,
   результат сохраняется в Photos (`PHPhotoLibrary`)

### Альтернативный флоу — режим наведения (AlignmentGuide), для портретов

1. Пользователь включает режим "Ai" (отдельная кнопка/toggle в UI, как на референсе)
2. Бабл "Ai Detecting the scene. Keep your phone still." — Vision ищет объект (1 раз, не в цикле)
3. На экране появляется кружок-мишень (`targetCompositionPoint`) и рамка с радужным градиентом
4. Бабл меняется на "Move your phone to align the composition point" — пользователь двигает
   телефон, `currentSubjectPoint` пересчитывается на каждом тике анализа (throttling 0.3–0.6 сек,
   тут нужна более высокая частота, чем в CompositionAnalyzer, т.к. это интерактивное наведение)
5. Как только `isAligned == true` — рамка/бабл меняются на "Perfect Composition", можно снимать
6. Если сцена тёмная — перед сохранением применяется `NightEnhancer.enhanceIfNeeded`

## 7. Технические требования

- Throttling анализа: не чаще 1 раза в 0.6 сек
- Vision-запросы выполнять на background queue; все `@Published`-обновления — на MainActor
- `AVCaptureVideoDataOutputSampleBufferDelegate` методы — `nonisolated`, с переходом на MainActor через `Task`
- Info.plist: `NSCameraUsageDescription`, `NSPhotoLibraryAddUsageDescription`
- Deployment target iOS 16.0, ориентация portrait
- Запрос разрешения камеры через `AVCaptureDevice.requestAccess(for: .video)` перед стартом сессии

## 8. Вне скоупа первой версии

- Точные film-эмуляции (LUT) — пока упрощённые CoreImage-фильтры, не реальные пресеты Fujifilm/Kodak
- Классификация конкретных объектов (люди/здания/еда) — используется общий saliency, не детекция классов
- Переключение между камерами (только back wide camera + цифровой зум)
- Настоящий multi-frame night mode (стекинг экспозиций) — только однокадровая имитация через CoreImage
- Автоматический подбор `targetCompositionPoint` под разные сюжеты (сейчас — фиксированный пресет
  для портрета на фоне пейзажа/города)

## 9. Критерии готовности

- Проект собирается через `xcodegen generate` без ручных правок `.xcodeproj`
- Приложение запускается на реальном устройстве, показывает live-preview
- При наведении на объект в кадре появляется рамка и кнопка зума в течение ~1 сек
- Рекомендация фильтра меняется при существенном изменении сцены (яркость/цвет)
- Кнопка затвора сохраняет фото с применённым фильтром в галерею
- В режиме AlignmentGuide кружок-мишень и текст-инструкция обновляются при движении телефона,
  `isAligned` корректно переключается при совпадении лица с целевой точкой
- В тёмной сцене итоговое фото заметно светлее/контрастнее исходного превью (`NightEnhancer`)
