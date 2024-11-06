#!/bin/bash

export GREEN='\033[0;32m'
export BLUE='\033[0;34m'
export GRAY='\033[1;37m'
export RED='\033[0;31m'
export NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Please run as root (using sudo)${RED}"
  echo -e "${NC}"
  exit
fi

echo -e "${GREEN}"
echo "  _____ _______   __     _  __ ______  __  __ ______ "
echo " / ____|__   __| /  \    | |/ /|  ____||  \/  |  ____|"
echo "| (___    | |   / /\ \   | ' / | |__   | \  / | |__   "
echo " \___ \   | |  / /__\ \  |  <  |  __|  | |\/| |  __|  "
echo " ____) |  | | / /____\ \ | . \ | |____ | |  | | |____ "
echo "|_____/   |_|/_/      \_\|_|\_\|______||_|  |_|______|"
echo -e "${NC}"
echo -e "${GRAY}======================================================${NC}"
echo -e "${GRAY} Welcome to STAKEME script edit validator on STORYSCAN ${NC}"
echo -e "${GRAY}======================================================${NC}"
echo -e "${BLUE}Installing Python dependencies...${NC}"
pip3 install --quiet web3 requests
echo -e "${BLUE}Generating JSON...${NC}"
read_input() {
  local prompt=$1
  local var
  while true; do
    read -p "$(echo -e "${BLUE}${prompt}${NC}")" var
    if [[ -z "$var" || "$var" =~ [[:cntrl:]] ]]; then
      echo -e "${RED}This field is required! Please enter a valid value.${NC}"
    else
      echo "$var"
      break
    fi
  done
}
read_optional_input() {
  local prompt=$1
  local var
  read -p "$(echo -e "${GRAY}${prompt} (press Enter to skip): ${GRAY}")" var
  if [[ -z "$var" || "$var" =~ [[:cntrl:]] ]]; then
    echo "\"\""
  else
    echo "\"$var\""
  fi
}
address=$(read_input "Enter address: ")
moniker=$(read_input "Enter moniker: ")
details=$(read_input "Enter details: ")
banner=$(read_optional_input "Enter banner")
avatar=$(read_optional_input "Enter avatar")
twitterUrl=$(read_optional_input "Enter twitterUrl")
githubUrl=$(read_optional_input "Enter githubUrl")
webUrl=$(read_optional_input "Enter webUrl")
identity=$(read_optional_input "Enter identity")
securityContact=$(read_optional_input "Enter securityContact")
json=$(cat <<EOF
{
  "address": "$address",
  "moniker": "$moniker",
  "details": "$details",
  "banner": $banner,
  "avatar": $avatar,
  "twitterUrl": $twitterUrl,
  "githubUrl": $githubUrl,
  "webUrl": $webUrl,
  "identity": $identity,
  "securityContact": $securityContact
}
EOF
)
echo -e "\n${GREEN}Generated JSON:${NC}"
echo -e "${GRAY}------------------------------------${NC}"
echo "$json" | jq .
echo -e "${GRAY}------------------------------------${NC}"
echo "$json" > "data.json"
echo -e "${GREEN}JSON saved to data.json${NC}"
cat > validator_script.py << 'EOF'
import json
import os
from web3 import Web3
import requests
from eth_account.messages import encode_defunct
GREEN = os.getenv("GREEN", "\033[0;32m")
BLUE = os.getenv("BLUE", "\033[0;34m")
GRAY = os.getenv("GRAY", "\033[1;37m")
RED = os.getenv("RED", "\033[0;31m")
NC = os.getenv("NC", "\033[0m")
def run_command(command):
    os.system(command)
def get_private_key():
    user_home = os.path.expanduser("~")
    print("Select a method to obtain the private key:")
    print("1. Enter the private key manually")
    print("2. Get a private key from the node (if you run the script next to the node)")
    choice = input("Your choice (1/2): ")
    if choice == "1":
        private_key = input("Enter your private key: ").strip()
    elif choice == "2":
        run_command("story validator export --export-evm-key")
        file_path = os.path.join(user_home, ".story", "story", "config", "private_key.txt")
        if os.path.exists(file_path):
            with open(file_path, "r") as file:
                private_key_line = file.read().strip()
                if private_key_line.startswith("PRIVATE_KEY="):
                    private_key = private_key_line.split("PRIVATE_KEY=")[1].strip()
                else:
                    private_key = private_key_line
        else:
            print(f"{RED}The file {file_path} was not found. Ensure you have exported the key correctly.{NC}")
            return None
    else:
        print("Invalid choice")
        return None
    return private_key
def read_validator_info_json():
    validator_json_path = "data.json"
    try:
        with open(validator_json_path, "r") as file:
            validator_data = json.load(file)
        return validator_data
    except FileNotFoundError:
        print(f"{RED}File data.json not found. Please ensure it exists in the directory.{NC}")
        return None
    except json.JSONDecodeError:
        print(f"{RED}Error decoding JSON from data.json. Check file format.{NC}")
        return None
def sign_message(private_key, message):
    try:
        w3 = Web3()
        message_to_sign = encode_defunct(text=message)
        signed_message = w3.eth.account.sign_message(message_to_sign, private_key=private_key)
        return "0x" + signed_message.signature.hex()
    except ValueError:
        print(f"{RED}Invalid private key format. Please verify your key.{NC}")
        return None
def send_post_request(data):
    url = "https://api.odyssey-0.storyscan.app/validators/verify"
    headers = {'Content-Type': 'application/json'}
    try:
        response = requests.post(url, headers=headers, json=data)
        response.raise_for_status()
        response_data = response.json()
        if response_data.get("success"):
            print(f"{GREEN}Validator successfully updated on STORYSCAN. Changes will reflect in 1-2 minutes.{NC}")
        else:
            print(f"{RED}Unexpected response: {response_data}{NC}")
    except requests.exceptions.HTTPError as err:
        print(f"{RED}HTTP error: {err.response.status_code} - {err.response.text}{NC}")
    except Exception as e:
        print(f"{RED}Request error: {e}{NC}")
def main():
    private_key = get_private_key()
    if not private_key:
        print(f"{RED}Failed to obtain private key{NC}")
        return
    validator_data = read_validator_info_json()
    if not validator_data:
        print(f"{RED}Failed to read validator information as JSON{NC}")
        return
    message_data = {key: validator_data[key] for key in validator_data if key != "signature"}
    message_to_sign = json.dumps(message_data, separators=(',', ':'), ensure_ascii=False)
    signature = sign_message(private_key, message_to_sign)
    if not signature:
        print(f"{RED}Signature generation failed{NC}")
        return
    validator_data["signature"] = signature
    send_post_request(validator_data)
if __name__ == "__main__":
    main()
EOF
echo -e "${BLUE}Running Python script...${NC}"
sudo -u "$SUDO_USER" python3 validator_script.py
rm -f validator_script.py data.json
