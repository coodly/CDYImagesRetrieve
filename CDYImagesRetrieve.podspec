Pod::Spec.new do |spec|
  spec.name         = 'CDYImagesRetrieve'
  spec.version      = '0.1.0'
  spec.summary      = "Base code for images async retrieve and caching"
  spec.homepage     = "https://github.com/coodly/CDYImagesRetrieve"
  spec.author       = { "Jaanus Siim" => "jaanus@coodly.com" }
  spec.source       = { :git => "https://github.com/coodly/CDYImagesRetrieve.git", :tag => "v#{spec.version}" }
  spec.license      = { :type => 'Apache 2', :file => 'LICENSE' }
  spec.requires_arc = true

  spec.subspec 'Core' do |ss|
    ss.platform = :ios, '7.0'
    ss.source_files = 'Core/*.{h,m}'
    ss.dependency 'AFNetworking'
    #ss.dependency 'CDYImageScale', :git => 'https://github.com/coodly/CDYImageScale.git'
  end
end
