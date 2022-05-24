# Script to grant or revoke superadmin from a Contrast user
# Author: josh.anderson@contrastsecurity.com

import argparse
import logging
import sys

from contrast_api import contrast_instance_from_json, load_config

args_parser = argparse.ArgumentParser(
    description="Grant or revoke superadmin from a user in Contrast."
)
# Required arguments
args_parser.add_argument(
    help="Action to take - grant|revoke superadmin.",
    metavar="action",
    dest="action",
    type=str,
    choices=["grant", "revoke"],
)
args_parser.add_argument(
    help="ID of Account to act on - email address/username.",
    metavar="account",
    dest="account",
    type=str,
)

args = args_parser.parse_args()


logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__file__)

config = load_config()
contrast = contrast_instance_from_json(config)
if not contrast.test_connection():
    sys.exit(1)
profile_info = contrast.api_request("profile")
if profile_info["user"]["superadmin_role"] != "SUPERADMIN":
    logger.error("Logged in user is not SUPERADMIN, exiting")
    sys.exit(1)

user_to_update = contrast.api_request(f"superadmin/users/{args.account}")
if not user_to_update["success"]:
    logger.error(
        f'Unable to lookup user {args.account} - server reply: {user_to_update.get("messages")}'
    )
    sys.exit(1)

if args.action == "grant" and user_to_update["user"]["superadmin_role"] == "SUPERADMIN":
    print("User is already superadmin, nothing to do")
    sys.exit()

method = "PUT" if args.action == "grant" else "DELETE"

action_response = contrast.api_request(
    f"superadmin/users/{args.account}/superadmin", method
)
if action_response["success"]:
    print("\n".join(action_response["messages"]))
else:
    logger.error(
        f'Action failed - server reply: {" ".join(action_response["messages"])}'
    )
    sys.exit(1)
