# jmux — Homebrew formula
#
# Lives here so it is versioned with the code it installs; release.sh copies the
# bumped copy into the tap repo (jarredkenny/homebrew-tap).
#
# NOTE: this is not a bottle. A bottle is a prebuilt keg Homebrew produces from
# a formula; this pours an upstream binary tarball, which is a formula whose
# `url` happens to be a precompiled archive. `brew install --build-from-source`
# is therefore meaningless here — there is no source build to fall back to.
#
# Every sha256 carries a trailing `# <platform>` comment. release.sh's bumper
# matches on those tags rather than on position, because a formula has several
# identical-looking sha256 lines and pairing one with the wrong architecture
# would install the wrong binary and still pass its own integrity check.
class Jmux < Formula
  desc "Terminal workspace for agentic development"
  homepage "https://github.com/jarredkenny/jmux"
  version "0.26.0"
  license "AGPL-3.0-only"

  # tmux is the one hard runtime requirement, and Homebrew can guarantee it —
  # which is a real advantage over the shell installer, where jmux has to
  # detect a missing tmux itself and ask.
  depends_on "tmux"

  on_macos do
    on_arm do
      url "https://github.com/jarredkenny/jmux/releases/download/v#{version}/jmux-#{version}-darwin-arm64.tar.gz"
      sha256 "d7c58009a833d867b43039abb8469f25dc11d9006970a46206ac89d7f1a7ce97" # darwin-arm64
    end
    on_intel do
      url "https://github.com/jarredkenny/jmux/releases/download/v#{version}/jmux-#{version}-darwin-x64.tar.gz"
      sha256 "aaf7ee482cb5e1319574656d4674dd1bba57e6977de71024a629259c95218ee4" # darwin-x64
    end
  end

  # Linuxbrew works on glibc. Alpine/musl is unsupported and cannot be fixed
  # here: bun-pty ships no musl native library, so a musl build would install
  # cleanly and then fail on the first pty spawn.
  on_linux do
    on_arm do
      url "https://github.com/jarredkenny/jmux/releases/download/v#{version}/jmux-#{version}-linux-arm64.tar.gz"
      sha256 "5f6aaca4a81fc9755d7e4d649b67efd8d696d8bad21c4adcb0788f74f9865394" # linux-arm64
    end
    on_intel do
      # The baseline build, deliberately. Homebrew cannot branch on whether the
      # host CPU has AVX2, and the standard build dies with an illegal
      # instruction on CPUs that lack it. The shell installer *can* check
      # /proc/cpuinfo and picks the faster build there; here, correctness on
      # every x86-64 machine is worth more than a difference no one running a
      # terminal UI can perceive.
      url "https://github.com/jarredkenny/jmux/releases/download/v#{version}/jmux-#{version}-linux-x64-baseline.tar.gz"
      sha256 "910bcec0f255ddc8eb08371e5e16216dcaddea8dae927a77d26ce1fe2f3d1f9f" # linux-x64-baseline
    end
  end

  def install
    bin.install "jmux"
  end

  def caveats
    <<~EOS
      Teach your agents the jmux control CLI:
        jmux --install-skill

      Install agent state hooks (Claude Code, Codex, pi):
        jmux --install-agent-hooks

      Both write into those tools' own config. To reverse them before
      uninstalling jmux:
        jmux --uninstall-integrations
    EOS
  end

  test do
    # `--version` exits before any of the interesting startup work, so on its
    # own it proves almost nothing. The second assertion is the real one: boot
    # against a private tmux socket and confirm the server came up with jmux's
    # materialized config, which exercises asset materialization, the tmux
    # spawn, and the config path all at once.
    assert_match version.to_s, shell_output("#{bin/"jmux"} --version")

    socket = "jmux-brew-test-#{Process.pid}"
    require "pty"
    begin
      PTY.spawn(bin/"jmux", "--socket", socket) do |_r, _w, pid|
        sleep 6
        detach = shell_output("tmux -L #{socket} show-options -g detach-on-destroy 2>/dev/null")
        Process.kill("TERM", pid)
        assert_match "off", detach
      end
    ensure
      system "tmux", "-L", socket, "kill-server"
    end
  end
end
