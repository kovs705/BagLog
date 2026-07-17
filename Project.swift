import ProjectDescription

let project = Project(
    name: "BagLog",
    options: .options(
        disableBundleAccessors: false,
        disableSynthesizedResourceAccessors: false,
        textSettings: .textSettings(
            usesTabs: false,
            indentWidth: 4,
            tabWidth: 4,
            wrapsLines: true
        )
    ),
    packages: [
        .local(path: "BagLogPackage"),
        .remote(url: "https://github.com/kovs705/PreviewDebugger", requirement: .branch("main")),
        .remote(url: "https://github.com/kovs705/AccessDenied.git", requirement: .branch("main"))
    ],
    settings: .settings(
        base: [
            "MARKETING_VERSION": "1.0",
            "DEVELOPMENT_TEAM": "5PVHGUKPAW",
            "COMPILATION_CACHE_ENABLE_CACHING": "YES"
        ],
        configurations: [
            .debug(name: "Debug", settings: [
                "EAGER_LINKING": "YES"
            ])
        ]
    ),
    targets: [
        // MARK: - Design System Module
        .target(
            name: "DesignSystem",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.CodingKovs.BagLog.DesignSystem",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .default,
            sources: [
                "DesignSystem/**"
            ],
            resources: [
                "DesignSystem/Resources/**"
            ],
            dependencies: [],
            settings: .settings(
                base: [
                    "GENERATE_INFOPLIST_FILE": "YES",
                    "PRODUCT_BUNDLE_IDENTIFIER": "com.CodingKovs.BagLog.DesignSystem",
                    "DEFINES_MODULE": "YES"
                ],
                configurations: [
                    .debug(name: "Debug", settings: [
                        "BUILD_LIBRARY_FOR_DISTRIBUTION": "NO"
                    ]),
                    .release(name: "Release", settings: [
                        "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"
                    ])
                ]
            )
        ),

        // MARK: - Domain Module
//        .target(
//            name: "DataStore",
//            destinations: .iOS,
//            product: .framework,
//            bundleId: "com.CodingKovs.BagLog.DataStore",
//            deploymentTargets: .iOS("26.0"),
//            infoPlist: .default,
//            sources: [
//                "DataStore/**"
//            ],
//            settings: .settings(
//                base: [
//                    "GENERATE_INFOPLIST_FILE": "YES",
//                    "PRODUCT_BUNDLE_IDENTIFIER": "com.CodingKovs.BagLog.Domain",
//                    "DEFINES_MODULE": "YES",
//                    "BUILD_LIBRARY_FOR_DISTRIBUTION": "YES"
//                ]
//            )
//        ),

        // MARK: - Services Module
        .target(
            name: "Services",
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.CodingKovs.BagLog.Services",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .default,
            sources: [
                "Services/**"
            ],
            dependencies: [],
            settings: .settings(
                base: [
                    "GENERATE_INFOPLIST_FILE": "YES",
                    "PRODUCT_BUNDLE_IDENTIFIER": "com.CodingKovs.BagLog.Services",
                    "DEFINES_MODULE": "YES"
                ]
            )
        ),

        // Main App Target
        .target(
            name: "BagLog",
            destinations: .iOS,
            product: .app,
            bundleId: "com.CodingKovs.BagLog",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .extendingDefault(with: [
                "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
                "UISupportedInterfaceOrientations~ipad": [
                    "UIInterfaceOrientationLandscapeLeft",
                    "UIInterfaceOrientationLandscapeRight",
                    "UIInterfaceOrientationPortrait",
                    "UIInterfaceOrientationPortraitUpsideDown"
                ],
                "UIAppFonts": [
                    "haxrcorp-4089.ttf",
                    "helvb08.ttf",
                    "Born2bSportyV2.ttf"
                ],
                "ITSAppUsesNonExemptEncryption": false,
                "NSCalendarsFullAccessUsageDescription": "We need access to your calendar to display events.",
                "NSRemindersFullAccessUsageDescription": "To work with your tasks.",
                "NSLocationWhenInUseUsageDescription": "For proper working of the map.",
                "NSPhotoLibraryAddUsageDescription": "To add new stickers on the device",
                "UTExportedTypeDeclarations": [
                    [
                        "UTTypeIdentifier": "com.codingkovs.BagLog.backup",
                        "UTTypeDescription": "BagLog Backup",
                        "UTTypeConformsTo": ["public.data"],
                        "UTTypeTagSpecification": [
                            "public.filename-extension": ["baglogbackup"]
                        ]
                    ],
                    [
                        "UTTypeIdentifier": "com.codingkovs.BagLog.kit-item",
                        "UTTypeDescription": "BagLog Kit Item",
                        "UTTypeConformsTo": ["public.data"]
                    ],
                    [
                        "UTTypeIdentifier": "com.codingkovs.BagLog.kit-photo",
                        "UTTypeDescription": "BagLog Kit Photo",
                        "UTTypeConformsTo": ["public.data"]
                    ]
                ],
                "UILaunchScreen": [
                    "UIColor": "UIColor.black"
                ]
            ]),
            sources: [
                "BagLog/Application/**",
                "BagLog/Utility/**",
                "BagLog/Design System/**",
                "BagLog/Resources/**",
                "BagLog/Localization/**"
            ],
            resources: [
                "BagLog/Resources/**",
                "BagLog/Localization/**"
            ],
            entitlements: .file(path: "BagLog/BagLog.entitlements"),
            dependencies: [
                .target(name: "DesignSystem"),
                .target(name: "Services"),
                .package(product: "Persistence"),
                .package(product: "PreviewDebugger"),
                .package(product: "AccessDenied")
            ],
            settings: .settings(
                base: [
                    "GENERATE_INFOPLIST_FILE": "YES",
                    "PRODUCT_BUNDLE_IDENTIFIER": "com.CodingKovs.BagLog",
                    "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
                    "ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS": "YES",
                    "ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS": "YES",
                    "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
                    "CURRENT_PROJECT_VERSION": "$(MARKETING_VERSION)",
                    "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.productivity",
                    "MY_SETTING": "platform ${platform}"
                ]
            )
        ),

        // Tests Target
        .target(
            name: "BagLogTests",
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.CodingKovs.BagLog.Tests",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .default,
            sources: ["BagLogTests/**"],
            dependencies: [
                .target(name: "BagLog"),
                .target(name: "DesignSystem"),
                .target(name: "Services"),
                .package(product: "Persistence")
            ],
            settings: .settings(
                base: [
                    "GENERATE_INFOPLIST_FILE": "YES"
                ]
            )
        ),

        // UI Tests Target
        .target(
            name: "BagLogUITests",
            destinations: .iOS,
            product: .uiTests,
            bundleId: "com.CodingKovs.BagLog.UITests",
            deploymentTargets: .iOS("26.0"),
            infoPlist: .default,
            sources: ["BagLogUITests/**"],
            dependencies: [
                .target(name: "BagLog")
            ],
            settings: .settings(
                base: [
                    "GENERATE_INFOPLIST_FILE": "YES",
                    "PRODUCT_BUNDLE_IDENTIFIER": "com.CodingKovs.BagLog.UITests"
                ]
            )
        )
    ],
    additionalFiles: [
        "DesignSystem/README.md",
        "Services/README.md",
        "BagLogPackage/Package.swift",
        .glob(pattern: "BagLogPackage/Sources/**"),
        .glob(pattern: "BagLogPackage/Tests/**"),
        "VisionSticker/README.md",
        "BagLog/README.md",
        "BagLogTests/README.md"
    ]
)
