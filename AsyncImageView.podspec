Pod::Spec.new do |s|
  s.name         = "AsyncImageview"
  s.platform 	  = :ios, '5.0'
  s.summary      = "This is an async image view which holds the image in cache "
  s.homepage     = "https://github.com/jailanigithub/AsyncImageView"
  s.author       = { "Jailani" => "jailaninice@gmail.com" }
  s.source       = { :git => "https://github.com/jailanigithub/AsyncImageView.git"}
  s.source_files = '*.{h,m}'
  s.requires_arc = true
end