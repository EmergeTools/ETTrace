require 'open3'

def sh!(args, allow_failure: false, get_output: false, chdir: Dir.pwd, hide_cmd: false)
  raise "Wrong type: #{args.class}" unless args.is_a?(Array)
  if get_output
    stdout, stderr, result = Open3.capture3([args[0], args[0]], *(args.drop(1)), chdir: chdir)
    puts "Stderr:\n#{stderr}" if stderr.length > 0
    success = result.success?
  else
    success = system([args[0], args[0]], *(args.drop(1)), chdir: chdir)
    stdout = stderr = nil
  end
  raise "Command failed: #{hide_cmd ? '<redacted>' : args.to_s}" unless success || allow_failure
  [stdout, stderr, success]
end
