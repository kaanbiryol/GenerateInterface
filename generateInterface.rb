#!/usr/bin/env ruby
# Wrapper script that extracts Swift compiler arguments from Xcode build settings
# and invokes the generateInterface tool.
#
# Usage: ruby generateInterface.rb <module_name> [--print-only]
#
# Environment variables:
#   WORKSPACE    - Xcode workspace name (default: App.xcworkspace)
#   TOOL_PATH    - path to the generateInterface binary (default: tools/generateInterface)
#   MODULES_PATH - path to the modules directory (default: libraries)

require 'json'
require 'tempfile'

module_name = ARGV[0]
print_only = ARGV.include?('--print-only')

workspace = ENV.fetch('WORKSPACE', 'App.xcworkspace')
tool_path = ENV.fetch('TOOL_PATH', 'tools/generateInterface')
modules_path_name = ENV.fetch('MODULES_PATH', 'libraries')

puts "🔧 Getting project build settings..."
current_dir = Dir.pwd
cache_file = File.join(current_dir, "buildSettings_cache_#{module_name}.json")

if File.exist?(cache_file)
  puts "Using cached build settings for #{module_name}"
  buildSettings = JSON.parse(File.read(cache_file))
else
  puts "Generating new build settings for #{module_name}"
  buildSettings = JSON.parse(`xcodebuild -workspace #{workspace} -scheme "#{module_name}" -arch arm64 -sdk iphonesimulator -configuration "Debug" -showBuildSettingsForIndex -json 2>/dev/null`)
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
  modules_path = File.expand_path(File.join(current_dir, modules_path_name))

  puts "🔧 Generating module interface..."
  command = "#{File.join(current_dir, tool_path)} \
  \"#{project_swift_path}\" \
  \"#{module_name}\" \
  \"#{modules_path}\" \
  \"#{compilerArgsPath}\" \
  #{print_only ? "--print-only" : ""}"

  system(command)

ensure
  tempFile.unlink
end
