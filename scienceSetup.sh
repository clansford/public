#!/bin/bash

#explanations
#script works in conjuection witn scienceSetup.exp to move all user inputs to front. Tried to just have one but 
#  non-interactive homebrew is a pain in the ass. It requires super user priveleges yet can't be run as root and I didn't
#  feel like adding a user to the sudoers group if I can even do that for theses machines.
#Ibrew is used b/c the scientists can use python3.7, if they ever move on it can be removed. Side note, it can't be
#  deleted after installing python3.7 b/c it's used to run it.

# colors ################################################################################################################
GREEN='\033[0;32m'
CYAN='\033[1;36m'
ORANGE='\033[1;33m'
NC='\033[0m'

#get user info upfront
read -s -p $'\033[0;36mEnter your first name\033[0m\n' FIRSTNAME
read -s -p $'\033[0;36mEnter your last name\033[0m\n' LASTNAME
read -s -p $'\033[0;36mEnter your dexcom email address\033[0m\n' EMAIL
read -s -p $'\033[0;36mEnter your github ssh key passphrase\033[0m\n' GHPASSPHRASE
read -s -p $'\033[0;36mEnter your codecommit ssh key passphrase\033[0m\n' CCPASSPHRASE

#install homebrew
echo -e "${ORANGE}INSTALLING BREW${NC}"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo -e "${CYAN}Don't worry about the PATH warning it'll be handled in this setup${NC}"
(
	echo
	echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'
) >>$HOME/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
source $HOME/.zprofile
echo -e "${ORANGE}---------------------------------------------------------------------------------------------------${NC}"

#install ibrew (homebrew x86_64)
echo -e "${ORANGE}INSTALLING ROSETTA${NC}"
yes A | softwareupdate --install-rosetta
echo -e "${ORANGE}---------------------------------------------------------------------------------------------------${NC}"
echo -e "${ORANGE}INSTALLING IBREW${NC}"
arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
arch -x86_64 /usr/local/bin/brew install python@3.7
alias ibrew="arch -x86_64 /usr/local/bin/brew"
printf "alias ibrew=\"arch -x86_64 /usr/local/bin/brew\"" >>$HOME/.zshrc
printf "\nalias cl=\"clear\"" >>$HOME/.zshrc
printf "\nalias ll=\"ls -l\"" >>$HOME/.zshrc
printf "\nalias la=\"ls -la\"" >>$HOME/.zshrc
printf "\nalias ..=\"cd ..\"" >>$HOME/.zshrc
printf "\nalias ..2=\"cd ../..\"" >>$HOME/.zshrc
printf "\nalias ..3=\"cd ../../..\"" >>$HOME/.zshrc
printf "\nalias ..4=\"cd ../../../..\"" >>$HOME/.zshrc
printf "\nalias ..5=\"cd ../../../../..\"" >>$HOME/.zshrc
printf "\nalias ..u=\"cd \$HOME\"" >>$HOME/.zshrc
printf "\nalias :q=\"exit\"" >>$HOME/.zshrc
printf "\nalias pbc=\"pbcopy\"" >>$HOME/.zshrc
printf "\nalias pbp=\"pbpaste\"" >>$HOME/.zshrc

echo -e "${ORANGE}---------------------------------------------------------------------------------------------------${NC}"

#install brew packages used in the setup
echo -e "${ORANGE}INSTALLING BREW PACKAGES${NC}"
brew install -q parallel
brew install -q --cask gpg-suite #not in parallel so expect file can input password
#only put casks in parallel. (FFM, yes it's faster I tested it)
parallel brew install -q --cask ::: pycharm slack

#not in parallel becuase brew processes locking causes problems
brew install -q automake
brew install -q awscli
brew install -q cmocka
brew install -q doxygen
brew install -q gh
brew install -q git-lfs
brew install -q jq
brew install -q libtool
brew install -q pkg-config
brew install -q python@3.8
brew install -q suite-sparse
echo -e "${ORANGE}---------------------------------------------------------------------------------------------------${NC}"

echo -e "${ORANGE}INSTALLING GIT LFS${NC}"
git lfs install
echo -e "${ORANGE}---------------------------------------------------------------------------------------------------${NC}"

#gh access token setup
echo -e "${ORANGE}GITHUB ACCESS TOKEN SETUP${NC}"
read -s -p $'\033[0;36mPaste the github access token here then hit enter\033[0m\n' GHAT

touch $HOME/.zshenv
printf "export GITHUB_TOKEN=$GHAT" >>$HOME/.zshenv
source $HOME/.zshenv
gh auth status
echo -e "${ORANGE}---------------------------------------------------------------------------------------------------${NC}"

#aws
echo -e "${ORANGE}AWS SSH SETUP${NC}"
mkdir $HOME/.aws
touch $HOME/.aws/credentials
read -s -p $'\033[0;36mCopy the  \'Access Key\' id and paste it here then hit enter\033[0m\n' AWSACCESSKEYID
read -s -p $'\033[0;36mCopy the  \'Secret access key\' and paste it here then hit enter\033[0m\n' AWSSECRETACCESSKEY
printf "[default]\naws_access_key_id = $AWSACCESSKEYID\naws_secret_access_key = $AWSSECRETACCESSKEY\n" >>$HOME/.aws/credentials
touch $HOME/.aws/config
printf "[default]\nregion = us-east-1" >>$HOME/.aws/config
aws sts get-caller-identity

firstLetter=${FIRSTNAME:0:1}
mkdir $HOME/.ssh
ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/codecommit_rsa" -N $CCPASSPHRASE
SSHPUBLICID=$(aws iam upload-ssh-public-key --user-name $firstLetter$LASTNAME --ssh-public-key-body "$(cat ~/.ssh/codecommit_rsa.pub)" | jq .SSHPublicKey.SSHPublicKeyId | tr -d \")
printf "Host git-codecommit.*.amazonaws.com
  User $SSHPUBLICID
  IdentityFile $HOME/.ssh/codecommit_rsa
  PubkeyAcceptedKeyTypes +ssh-rsa
  HostkeyAlgorithms +ssh-rsa\n" >>$HOME/.ssh/config
chmod 600 $HOME/.ssh/config
echo -e "${ORANGE}---------------------------------------------------------------------------------------------------${NC}"

#gpg key
echo -e "${ORANGE}GPG KEY SETUP${NC}"
gpg --full-gen-key --batch <(
	echo "Key-Type: 1"
	echo "Key-Length: 4096"
	echo "Subkey-Type: 1"
	echo "Subkey-Length: 4096"
	echo "Expire-Date: 0"
	echo "Name-Real: $FIRSTNAME $LASTNAME"
	echo "Name-Email: $EMAIL"
	echo "Passphrase: $GHPASSPHRASE"
)
GPGKEYID=$(gpg --list-secret-keys --keyid-format=long | sed 's/.*rsa4096\///' | sed 's/ .*//' | head -3 | tail -1)
echo -e "[user]
	name = $FIRSTNAME $LASTNAME 
	email = $EMAIL
	signingkey = $GPGKEYID

[filter \"lfs\"]
	required = true
	clean = git-lfs clean -- %f
	smudge = git-lfs smudge -- %f
	process = git-lfs filter-process

[core]
	editor = vim
	excludesfile = $HOME/.gitignore

[init]
	defaultBranch = main

[url \"git@github.com:\"]
	insteadOf = https://github.com/

[credential \"https://git-codecommit.us-east-1.amazonaws\.com\"]
	helper = !aws codecommit credential-helper \$@
	UseHttpPath = true" >>$HOME/.gitconfig
git config --global commit.gpgsign true
gpg --armor --export $GPGKEYID | gh gpg-key add -
echo -e "${ORANGE}---------------------------------------------------------------------------------------------------${NC}"

#github ssh key
echo -e "${ORANGE}GITHUB SSH SETUP${NC}"
ssh-keygen -t ed25519 -C $EMAIL -f "$HOME/.ssh/id_ed25519" -N $GHPASSPHRASE
printf "\nHost *.github.com
  AddKeysToAgent yes
  UseKeychain yes
  IdentityFile $HOME/.ssh/id_ed25519\n" >>$HOME/.ssh/config
gh ssh-key add $HOME/.ssh/id_ed25519.pub
echo -e "${ORANGE}---------------------------------------------------------------------------------------------------${NC}"

#clone repos
echo -e "${ORANGE}CLONING REPOS${NC}"
ssh-add $HOME/.ssh/codecommit_rsa
ssh-add $HOME/.ssh/id_ed25519
ssh-keyscan git-codecommit.us-east-1.amazonaws.com >>$HOME/.ssh/known_hosts
ssh-keyscan github.com >>$HOME/.ssh/known_hosts
mkdir $HOME/repos
cd $HOME/repos
git clone git@github.com:Type-Zero/rd-alg.git
git clone ssh://git-codecommit.us-east-1.amazonaws.com/v1/repos/kamino
git clone git@github.com:Type-Zero/sprinkles.git
git clone git@github.com:Type-Zero/agile-pony.git
echo -e "${ORANGE}---------------------------------------------------------------------------------------------------${NC}"

# docker setup, opening docker desktop won't work in vm becuase utm doesn't support a hypervisor
echo -e "${ORANGE}DOCKER SETUP${NC}"
curl --output $HOME/Downloads/Docker.dmg "https://desktop.docker.com/mac/main/arm64/Docker.dmg?utm_source=docker&utm_medium=webreferral&utm_campaign=dd-smartbutton&utm_location=module"
sudo hdiutil attach $HOME/Downloads/Docker.dmg
sudo /Volumes/Docker/Docker.app/Contents/MacOS/install --accept-license
sudo hdiutil detach /Volumes/Docker
echo -e "${ORANGE}---------------------------------------------------------------------------------------------------${NC}"
echo -e "${ORANGE}SOURCE ZSH FILES${NC}"

echo -e "${ORANGE}---------------------------------------------------------------------------------------------------${NC}"
source $HOME/.zshenv
source $HOME/.zprofile
source $HOME/.zshrc
echo -e "${ORANGE}INSTALLATION SCRIPT COMPLETE${NC}"
