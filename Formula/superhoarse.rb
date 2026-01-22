# typed: false
# frozen_string_literal: true

class Superhoarse < Formula
  desc "Privacy-focused, local voice-to-text macOS application"
  homepage "https://github.com/mheiber/superhoarse"
  url "https://github.com/mheiber/superhoarse.git",
      revision: "1f76b819187846e53ecb2beecd43eadeedd2eb65"
  version "1.0.0"
  license :cannot_represent # Closed-source per README

  head "https://github.com/mheiber/superhoarse.git", branch: "main"

  depends_on :macos => :ventura
  depends_on :xcode => ["14.0", :build]

  def install
    # Download model files using the project's script
    ohai "Downloading Parakeet speech recognition models (~607MB)..."
    system "./download_models.sh"

    # Build the Swift package
    ohai "Building Superhoarse..."
    system "swift", "build", "-c", "release", "--disable-sandbox"

    # Create the app bundle
    ohai "Creating application bundle..."
    app_bundle = prefix/"Superhoarse.app"
    mkdir_p app_bundle/"Contents/MacOS"
    mkdir_p app_bundle/"Contents/Resources"

    # Copy the binary
    cp ".build/release/Superhoarse", app_bundle/"Contents/MacOS/"
    chmod 0755, app_bundle/"Contents/MacOS/Superhoarse"

    # Copy Info.plist
    cp "Info.plist", app_bundle/"Contents/"

    # Copy resources (models)
    model_dir = buildpath/"Sources/Resources"
    cp_r Dir[model_dir/"*"], app_bundle/"Contents/Resources/"

    # Create symlink in bin for CLI access
    bin.write_exec_script app_bundle/"Contents/MacOS/Superhoarse"
  end

  def caveats
    <<~EOS
      Superhoarse has been installed to:
        #{prefix}/Superhoarse.app

      To use the app:
        1. Copy to /Applications: cp -R #{prefix}/Superhoarse.app /Applications/
           Or run directly: open #{prefix}/Superhoarse.app
        2. Grant Accessibility permission when prompted (required for text insertion)
        3. Grant Microphone permission when prompted
        4. Use ⌘⇧Space to start voice recording

      The app runs in the menu bar. Look for the Superhoarse icon.

      Note: First launch may take a moment while the speech model initializes.
    EOS
  end

  test do
    assert_predicate prefix/"Superhoarse.app/Contents/MacOS/Superhoarse", :executable?
  end
end
