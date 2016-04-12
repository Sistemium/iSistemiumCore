Pod::Spec.new do |s|
  s.name         = 'iSistemuimCore'
  s.version      = '1.0'
  s.summary      = 'iSistemiumCore for iSistemium apps'
  s.homepage     = 'https://github.com/Sistemium/iSistemiumCore'

  s.license      = 'MIT'
  s.author       = { 'Grigoriev Maxim' => 'grigoriev.maxim@gmail.com' }
  s.source       = { :git => 'https://github.com/Sistemium/iSistemiumCore.git', :branch => 'master'}
  s.platform     = :ios, '7.0'

  s.source_files = '*.{h,m}', 'Classes/**/*.{h,m,swift}', 'DataModel/*.{h,m}'
  s.resources = 'Storyboards/**/*.{storyboard,xib}', 'DataModel/*.{xcdatamodel,xcdatamodeld}', 'Resources/**/*'

  s.frameworks = 'WebKit'

  s.requires_arc = true

end

