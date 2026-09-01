#!/usr/bin/env ruby
# Puts PrivacyInfo.xcprivacy into the Runner target's Resources build phase on
# iOS and macOS.
#
# The manifests were written and committed and then did not ship, because a file
# sitting in a folder is not a file in a bundle — Xcode only copies what a target
# references. That is this project's wiring-gap pattern in Apple build
# configuration rather than Dart.
#
# Uses the `xcodeproj` gem, which is what CocoaPods itself edits projects with,
# rather than hand-editing project.pbxproj. A bad manual edit to that file has
# already cost this project real time once.
#
# Idempotent: re-running adds nothing. Worth keeping rather than doing once,
# because `flutter create` regenerating a Runner target would silently drop this
# again.
require "xcodeproj"

MANIFEST = "PrivacyInfo.xcprivacy".freeze

TARGETS = [
  { project: "apps/resonance/ios/Runner.xcodeproj",
    file: "apps/resonance/ios/Runner/#{MANIFEST}",
    group: "Runner" },
  { project: "apps/resonance/macos/Runner.xcodeproj",
    file: "apps/resonance/macos/Runner/#{MANIFEST}",
    group: "Runner" },
].freeze

changed = false

TARGETS.each do |spec|
  abort "missing #{spec[:file]}" unless File.exist?(spec[:file])

  project = Xcodeproj::Project.open(spec[:project])
  target = project.targets.find { |t| t.name == "Runner" }
  abort "no Runner target in #{spec[:project]}" if target.nil?

  phase = target.resources_build_phase
  already = phase.files.any? do |f|
    f.file_ref && File.basename(f.file_ref.path.to_s) == MANIFEST
  end

  if already
    puts "  already referenced  #{spec[:project]}"
    next
  end

  group = project.main_group.find_subpath(spec[:group], true)
  group.set_source_tree("<group>") if group.source_tree.nil?

  existing_ref = group.files.find { |f| File.basename(f.path.to_s) == MANIFEST }
  ref = existing_ref || group.new_reference(MANIFEST)

  phase.add_file_reference(ref)
  project.save
  changed = true
  puts "  added to Resources   #{spec[:project]}"
end

puts changed ? "\nProject files updated. Rebuild to see it in the bundle." :
               "\nNothing to do."
