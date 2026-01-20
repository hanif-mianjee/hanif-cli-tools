class HanifCli < Formula
  desc "Simple, extensible CLI for daily workflows"
  homepage "https://github.com/hanif-mianjee/hanif-cli-tools"
  url "https://github.com/hanif-mianjee/hanif-cli-tools/archive/v1.0.0.tar.gz"
  sha256 "SHA256_CHECKSUM_HERE"
  license "MIT"
  version "1.0.0"

  depends_on "bash"
  depends_on "git"

  def install
    # Install library files
    libexec.install Dir["lib"]
    
    # Install bin files
    bin.install "bin/hanif"
    
    # Fix shebang to use Homebrew's bash
    inreplace bin/"hanif", /^#!\/usr\/bin\/env bash/, "#!#{Formula["bash"].opt_bin}/bash"
  end

  test do
    # Test that the binary runs
    assert_match "hanif CLI v", shell_output("#{bin}/hanif version")
    
    # Test help command
    assert_match "Usage: hanif", shell_output("#{bin}/hanif help")
  end

  def caveats
    <<~EOS
      Hanif CLI has been installed!
      
      Get started:
        hanif help
        hanif git nf "my feature"
      
      Documentation:
        #{homepage}
    EOS
  end
end
