require "spec"
require "process"
require "./spec_helper"
require "../spec_helper"

private def exit_code_command(code)
  if {{flag?(:win32)}}
    {"cmd.exe", {"/c", "exit #{code}"}}
  else
    case code
    when 0
      {"true", [] of String}
    when 1
      {"false", [] of String}
    else
      {"/bin/sh", {"-c", "exit #{code}"}}
    end
  end
end

private def shell_command(command)
  if {{flag?(:win32)}}
    {"cmd.exe", {"/c", command}}
  else
    {"/bin/sh", {"-c", command}}
  end
end

private def stdin_to_stdout_command
  if {{flag?(:win32)}}
    # {"powershell.exe", {"-C", "$Input"}}
    {"C:\\Crystal\\cat.exe", [] of String}
  else
    {"/bin/cat", [] of String}
  end
end

describe Process do
  it "runs true" do
    process = Process.new(*exit_code_command(0))
    process.wait.exit_code.should eq(0)
  end

  it "runs false" do
    process = Process.new(*exit_code_command(1))
    process.wait.exit_code.should eq(1)
  end

  it "raises if command could not be executed" do
    expect_raises Errno do
      Process.new("foobarbaz")
    end
  end

  it "run waits for the process" do
    Process.run(*exit_code_command(0)).exit_code.should eq(0)
  end

  it "runs true in block" do
    Process.run(*exit_code_command(0)) { }
    $?.exit_code.should eq(0)
  end

  it "receives arguments in array" do
    command, args = exit_code_command(123)
    Process.run(command, args.to_a).exit_code.should eq(123)
  end

  it "receives arguments in tuple" do
    command, args = exit_code_command(123)
    Process.run(command, args.as(Tuple)).exit_code.should eq(123)
  end

  it "redirects output to /dev/null" do
    # This doesn't test anything but no output should be seen while running tests
    if {{flag?(:win32)}}
      command = "cmd.exe"
      args = {"/c", "dir"}
    else
      command = "/bin/ls"
      args = [] of String
    end
    Process.run(command, args, output: Process::Redirect::Close).exit_code.should eq(0)
  end

  it "gets output" do
    value = Process.run(*shell_command("echo hello")) do |proc|
      proc.output.gets_to_end
    end
    if {{flag?(:win32)}}
      value.should eq("hello\r\n")
    else
      value.should eq("hello\n")
    end
  end

  # TODO: reenable after implementing fibers/asyncio
  pending_win32 "sends input in IO" do
    value = Process.run(*stdin_to_stdout_command, input: IO::Memory.new("hello")) do |proc|
      proc.input?.should be_nil
      proc.output.gets_to_end
    end
    value.should eq("hello")
  end

  # TODO: reenable after implementing fibers/asyncio
  pending_win32 "sends output to IO" do
    output = IO::Memory.new
    Process.run(*shell_command("echo hello"), output: output)
    output.to_s.should eq("hello\n")
  end

  # TODO: reenable after implementing fibers/asyncio
  pending_win32 "sends error to IO" do
    error = IO::Memory.new
    Process.run(*shell_command("echo hello 1>&2"), error: error)
    error.to_s.should eq("hello\n")
  end

  it "controls process in block" do
    value = Process.run(*stdin_to_stdout_command, error: :inherit) do |proc|
      proc.input.print "hello"
      proc.input.close
      proc.output.gets_to_end
    end
    value.should eq("hello")
  end

  it "closes ios after block" do
    Process.run(*stdin_to_stdout_command) { }
    $?.exit_code.should eq(0)
  end

  it "chroot raises when unprivileged" do
    status, output = build_and_run <<-'CODE'
      begin
        Process.chroot("/usr")
        puts "FAIL"
      rescue ex : Errno
        puts (ex.errno == Errno::EPERM) ? "Success" : "FAIL: #{ex.message}"
      rescue ex
        puts "FAIL: #{ex.message}"
      end
    CODE

    status.success?.should be_true
    output.should eq("Success\n")
  end

  it "sets working directory" do
    parent = File.dirname(Dir.current)
    value = Process.run("pwd", shell: true, chdir: parent, output: Process::Redirect::Pipe) do |proc|
      proc.output.gets_to_end
    end
    value.should eq "#{parent}\n"
  end

  it "disallows passing arguments to nowhere" do
    expect_raises ArgumentError, /args.+@/ do
      Process.run("foo bar", {"baz"}, shell: true)
    end
  end

  it "looks up programs in the $PATH with a shell" do
    proc = Process.run("uname", {"-a"}, shell: true, output: Process::Redirect::Close)
    proc.exit_code.should eq(0)
  end

  it "allows passing huge argument lists to a shell" do
    proc = Process.new(%(echo "${@}"), {"a", "b"}, shell: true, output: Process::Redirect::Pipe)
    output = proc.output.gets_to_end
    proc.wait
    output.should eq "a b\n"
  end

  it "does not run shell code in the argument list" do
    proc = Process.new("echo", {"`echo hi`"}, shell: true, output: Process::Redirect::Pipe)
    output = proc.output.gets_to_end
    proc.wait
    output.should eq "`echo hi`\n"
  end

  describe "environ" do
    it "clears the environment" do
      value = Process.run("env", clear_env: true) do |proc|
        proc.output.gets_to_end
      end
      value.should eq("")
    end

    it "sets an environment variable" do
      env = {"FOO" => "bar"}
      value = Process.run("env", clear_env: true, env: env) do |proc|
        proc.output.gets_to_end
      end
      value.should eq("FOO=bar\n")
    end

    it "deletes an environment variable" do
      env = {"HOME" => nil}
      value = Process.run("env | egrep '^HOME='", env: env, shell: true) do |proc|
        proc.output.gets_to_end
      end
      value.should eq("")
    end
  end

  describe "kill" do
    it "kills a process" do
      process = fork { loop { } }
      process.kill(Signal::KILL).should be_nil
    end

    it "kills many process" do
      process1 = fork { loop { } }
      process2 = fork { loop { } }
      process1.kill(Signal::KILL).should be_nil
      process2.kill(Signal::KILL).should be_nil
    end
  end

  it "gets the pgid of a process id" do
    process = fork { loop { } }
    Process.pgid(process.pid).should be_a(Int32)
    process.kill(Signal::KILL)
    Process.pgid.should eq(Process.pgid(Process.pid))
  end

  it "can link processes together" do
    buffer = IO::Memory.new
    Process.run("/bin/cat") do |cat|
      Process.run("/bin/cat", input: cat.output, output: buffer) do
        1000.times { cat.input.puts "line" }
        cat.close
      end
    end
    buffer.to_s.lines.size.should eq(1000)
  end

  it "executes the new process with exec" do
    with_tempfile("crystal-spec-exec") do |path|
      File.exists?(path).should be_false

      fork = Process.fork do
        Process.exec("/usr/bin/env", {"touch", path})
      end
      fork.wait

      File.exists?(path).should be_true
    end
  end

  it "checks for existence" do
    # We can't reliably check whether it ever returns false, since we can't predict
    # how PIDs are used by the system, a new process might be spawned in between
    # reaping the one we would spawn and checking for it, using the now available
    # pid.
    Process.exists?(Process.ppid).should be_true

    process = Process.fork { sleep 5 }
    process.exists?.should be_true
    process.terminated?.should be_false

    # Kill, zombie now
    process.kill
    process.exists?.should be_true
    process.terminated?.should be_false

    # Reap, gone now
    process.wait
    process.exists?.should be_false
    process.terminated?.should be_true
  end

  describe "executable_path" do
    it "searches executable" do
      Process.executable_path.should be_a(String | Nil)
    end
  end

  describe "find_executable" do
    pwd = Process::INITIAL_PWD
    crystal_path = File.join(pwd, "bin", "crystal")

    pending_win32 "resolves absolute executable" do
      Process.find_executable(File.join(pwd, "bin", "crystal")).should eq(crystal_path)
    end

    pending_win32 "resolves relative executable" do
      Process.find_executable(File.join("bin", "crystal")).should eq(crystal_path)
      Process.find_executable(File.join("..", File.basename(pwd), "bin", "crystal")).should eq(crystal_path)
    end

    pending_win32 "searches within PATH" do
      (path = Process.find_executable("ls")).should_not be_nil
      path.not_nil!.should match(/#{File::SEPARATOR}ls$/)

      (path = Process.find_executable("crystal")).should_not be_nil
      path.not_nil!.should match(/#{File::SEPARATOR}crystal$/)

      Process.find_executable("some_very_unlikely_file_to_exist").should be_nil
    end
  end
end
