#!/usr/bin/env ruby
require 'json'
require 'tempfile'

module_name = ARGV[0]
print_only = ARGV.include?('--print-only')

puts "🔧 Getting project build settings..."
current_dir = Dir.pwd
cache_file = File.join(current_dir, "buildSettings_cache_#{module_name}.json")

if File.exist?(cache_file)
  puts "Using cached build settings for #{module_name}"
  buildSettings = JSON.parse(File.read(cache_file))
else
  puts "Generating new build settings for #{module_name}"
  buildSettings = JSON.parse(`xcodebuild -workspace App.xcworkspace -scheme "#{module_name}" -arch arm64 -sdk iphonesimulator -configuration "Debug" -showBuildSettingsForIndex -json 2>/dev/null`)
  File.write(cache_file, JSON.dump(buildSettings))
end

moduleBuildSettings = buildSettings[module_name]
firstSwiftFileInModuleBuildSettings = moduleBuildSettings.keys.first
compilerArgs = moduleBuildSettings[firstSwiftFileInModuleBuildSettings]["swiftASTCommandArguments"]
compilerArgs = compilerArgs.reject { |arg| arg.include?("-module-name") || arg == module_name }

tempFile = Tempfile.new('compilerArgs')
begin
  compilerArgs.each do |arg|
    tempFile.puts(arg)
    puts arg if print_only
  end
  tempFile.close

  compilerArgsPath = tempFile.path
  puts "📝 Compiler arguments written to temporary file: #{compilerArgsPath}"

  project_swift_path = File.expand_path(File.join(current_dir, 'Project.swift'))
  modules_path = File.expand_path(File.join(current_dir, 'libraries'))

  puts "🔧 Generating module interface..."
  command = "#{current_dir}/tools/generateInterface \
  \"#{project_swift_path}\" \
  \"#{module_name}\" \
  \"#{modules_path}\" \
  \"#{compilerArgsPath}\" \
  #{print_only ? "--print-only" : ""}"
  
  system(command)

ensure
  tempFile.unlink
end
