Pod::Spec.new do |s|
  s.name         = 'iSistemiumCore'
  s.version      = '1.0'
  s.summary      = 'iSistemiumCore for iSistemium apps'
  s.homepage     = 'https://github.com/Sistemium/iSistemiumCore'

  s.license      = 'MIT'
  s.author       = { 'Grigoriev Maxim' => 'grigoriev.maxim@gmail.com' }
  s.source       = { :git => 'https://github.com/Sistemium/iSistemiumCore.git', :branch => 'master'}
  s.platform     = :ios, '8.0'

  s.source_files = 'iSistemiumCore/*.{h,m}', 'iSistemiumCore/Classes/**/*.{h,m,swift}', 'iSistemiumCore/DataModel/*.{h,m}'
  s.resources = 'iSistemiumCore/Storyboards/**/*.{storyboard,xib}', 'iSistemiumCore/DataModel/*.{xcdatamodel,xcdatamodeld}', 'iSistemiumCore/Resources/**/*'

  s.frameworks = 'WebKit'

  s.requires_arc = true

  s.dependency 'KiteJSONValidator', '~> 0.2.3'
  s.dependency 'Reachability', '~> 3.1.0'
  s.dependency 'Crashlytics', '~> 3.7.0'
  s.dependency 'JNKeychain', '~> 0.1.4'

end

