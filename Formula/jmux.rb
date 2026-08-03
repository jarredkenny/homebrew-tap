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
  version "0.27.2"
  license "AGPL-3.0-only"

  # tmux is the one hard runtime requirement, and Homebrew can guarantee it —
  # which is a real advantage over the shell installer, where jmux has to
  # detect a missing tmux itself and ask.
  depends_on "tmux"

  on_macos do
    on_arm do
      url "https://github.com/jarredkenny/jmux/releases/download/v#{version}/jmux-#{version}-darwin-arm64.tar.gz"
      sha256 "4209894c6162fbf75039c1de0b12d0aab3ddc64ca3a83fc6ee1a5d0954f1503a" # darwin-arm64
    end
    on_intel do
      url "https://github.com/jarredkenny/jmux/releases/download/v#{version}/jmux-#{version}-darwin-x64.tar.gz"
      sha256 "2a7a66e48396014946dc26885933d4daf8e7f9b3fc8ba16fad59229ff98bbe4f" # darwin-x64
    end
  end

  # Linuxbrew works on glibc. Alpine/musl is unsupported and cannot be fixed
  # here: bun-pty ships no musl native library, so a musl build would install
  # cleanly and then fail on the first pty spawn.
  on_linux do
    on_arm do
      url "https://github.com/jarredkenny/jmux/releases/download/v#{version}/jmux-#{version}-linux-arm64.tar.gz"
      sha256 "469ba89947a86f038384f4385407a2455781c42339a0c042db5340ce342b82ac" # linux-arm64
    end
    on_intel do
      # The baseline build, deliberately. Homebrew cannot branch on whether the
      # host CPU has AVX2, and the standard build dies with an illegal
      # instruction on CPUs that lack it. The shell installer *can* check
      # /proc/cpuinfo and picks the faster build there; here, correctness on
      # every x86-64 machine is worth more than a difference no one running a
      # terminal UI can perceive.
      url "https://github.com/jarredkenny/jmux/releases/download/v#{version}/jmux-#{version}-linux-x64-baseline.tar.gz"
      sha256 "217c69f50163646d3314de29c38afc921f411c017eba8d2c5690f70a3f81818f" # linux-x64-baseline
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
    assert_match version.to_s, shell_output("#{bin/"jmux"} --version")

    # The real risk in a compiled binary is asset materialization. Under
    # `bun build --compile` the bundle lives on a virtual filesystem that tmux —
    # a separate process — cannot read, so jmux must write its tmux config out
    # to a real path before spawning tmux. If that regresses, the binary starts
    # and then fails in a way `--version` would never catch.
    #
    # `--install-skill` drives exactly that path, and needs no tmux, no pty and
    # no writable /tmp, so it is deterministic inside the test sandbox. Booting
    # the full TUI here is not: Homebrew's sandbox stops tmux from starting a
    # server, and the failure looks like jmux's rather than the sandbox's.
    ENV["HOME"] = testpath
    ENV["XDG_DATA_HOME"] = testpath/"data"
    ENV["CLAUDE_CONFIG_DIR"] = testpath/"claude"

    system bin/"jmux", "--install-skill"
    assert_path_exists testpath/"claude/skills/jmux-control/SKILL.md"

    tmux_conf = Dir[testpath/"data/jmux/assets/*/config/tmux.conf"].first
    refute_nil tmux_conf, "jmux did not materialize its tmux config"
    assert_match "source-file", File.read(tmux_conf)
  end
end
