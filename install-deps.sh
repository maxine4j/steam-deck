# Clone wow-ui-source for Blizzard UI source code
git clone https://github.com/Gethe/wow-ui-source .libraries/wow-ui-source
cd .libraries/wow-ui-source
# Remove .git directory
rm -rf .git
# Keep only the Interface folder, delete everything else
find . -mindepth 1 -maxdepth 1 ! -name 'Interface' -exec rm -rf {} +
cd ../..

# clone console port for reference
git clone https://github.com/seblindfors/ConsolePort .libraries/ConsolePort
cd .libraries/ConsolePort
# Remove .git directory
rm -rf .git
cd ../..

# better bags for reference
git clone https://github.com/Cidan/BetterBags .libraries/BetterBags
cd .libraries/BetterBags
# Remove .git directory
rm -rf .git
cd ../..