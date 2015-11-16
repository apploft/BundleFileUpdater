Pod::Spec.new do |s|

  s.name         = "BundleFileUpdater"
  s.version      = "0.0.1"
  s.summary      = "Deliver your app with up-to-date local resource files and update them dynamically from a remote url."

  s.description  = <<-DESC
  Deliver your app with up-to-date local resource files in your app bundle and update them dynamically from a remote url both with every build and dynamically at runtime. Your users will always have the latest resource files' version without the need for a new app submission.
                   DESC

  s.homepage     = "https://github.com/apploft/BundleFileUpdater"

  s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author       = { "Michael Kamphausen" => "michael.kamphausen@apploft.de" }
  
  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.9"

  s.source       = { :git => "https://github.com/apploft/BundleFileUpdater.git", :tag => s.version.to_s }

  s.source_files = "BundleFileUpdater/**/*.{swift}"
  
  s.framework    = "Foundation"

  s.requires_arc = true

end
