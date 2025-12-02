Pod::Spec.new do |s|
  s.name             = 'FastULID'
  s.version          = '1.0.0'
  s.summary          = 'High-performance ULID (Universally Unique Lexicographically Sortable Identifier) implementation in Swift'
  s.description      = <<-DESC
    A highly optimized ULID implementation in Swift with 3-10x performance improvements.
    Features include clock drift handling, configurable time providers, batch generation,
    and full compatibility with the original yaslab/ULID.swift API.
  DESC

  s.homepage         = 'https://github.com/elijahdou/FastULID'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'FastULID Contributors' => 'elijahdou@gmail.com' }
  s.source           = { :git => 'https://github.com/elijahdou/FastULID.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.0'
  s.osx.deployment_target = '12.0'
  s.watchos.deployment_target = '8.0'
  s.tvos.deployment_target = '15.0'

  s.swift_version = '5.9'
  
  s.source_files = 'Sources/FastULID/**/*.swift'
  
  s.frameworks = 'Foundation'
end

