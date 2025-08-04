#!/usr/bin/env ruby
require 'xcodeproj'

script_dir = File.expand_path(File.dirname(__FILE__))
project_path = File.expand_path('../macos/Runner.xcodeproj', script_dir)
resource_path = File.expand_path('../macos/Runner/Resources/ffmpeg', script_dir)

unless File.exist?(resource_path)
  puts "Error: #{resource_path} does not exist."
  exit 1
end

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == 'Runner' }

# Locate or create the Resources group
group = project.main_group.find_subpath('Resources', true)
group.set_source_tree('SOURCE_ROOT')

# Check if file reference already exists
existing_ref = group.files.find { |f| f.path == 'Runner/Resources/ffmpeg' }

unless existing_ref
  puts "Adding ffmpeg to Resources group..."
  existing_ref = group.new_file('Runner/Resources/ffmpeg')
else
  puts "ffmpeg already present in Runner/Resources group."
end

# Find or create Copy Bundle Resources build phase
resource_phase = target.copy_files_build_phases.find do |phase|
  phase.name == 'Copy Bundle Resources' || phase.symbol_dst_subfolder_spec == :resources
end

unless resource_phase
  puts "Creating new Copy Bundle Resources phase..."
  resource_phase = target.new_copy_files_build_phase('Copy Bundle Resources')
  resource_phase.symbol_dst_subfolder_spec = :resources
end

if resource_phase.files_references.include?(existing_ref)
  puts "ffmpeg already listed in Copy Bundle Resources."
else
  puts "Adding ffmpeg to Copy Bundle Resources..."
  resource_phase.add_file_reference(existing_ref)
end

# Add or verify a Run Script phase for chmod +x
script_text = 'chmod +x "${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/Resources/ffmpeg"'
unless target.shell_script_build_phases.any? { |p| p.shell_script.include?(script_text) }
  puts "Adding Run Script Phase to make ffmpeg executable..."
  phase = target.new_shell_script_build_phase('Make ffmpeg Executable')
  phase.shell_script = script_text
else
  puts "Run Script Phase already handles chmod +x for ffmpeg."
end

project.save
puts "Done: ffmpeg configured in Xcode project."
