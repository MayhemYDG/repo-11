# Script to create an application access group on the Contrast TeamServer
# Author: josh.anderson@contrastsecurity.com

import argparse
import logging
import sys

from contrast_api import contrast_instance_from_json, load_config

args_parser = argparse.ArgumentParser(
    description="Create an application access group on Contrast."
)
# Required arguments
args_parser.add_argument(
    "-n",
    "--group-name",
    "--group-name",
    help="Name of the group you want to create.",
    type=str,
    required=True,
)
args_parser.add_argument(
    "-r",
    "--role",
    help="Role to give users allocated to this group's applications.",
    choices=["NO_ACCESS", "VIEW", "EDIT", "RULES_ADMIN", "ADMIN"],
    type=str.upper,
    required=True,
)
args_parser.add_argument(
    "-o",
    "--org-id",
    "--organization-id",
    help="ID of the organization to create this group in.",
    type=str,
    required=True,
)
args = args_parser.parse_args()


logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__file__)

config = load_config()
contrast = contrast_instance_from_json(config)

body = {
    "name": args.group_name,
    "scope": {"app_scope": {"exceptions": [], "onboard_role": args.role}},
    "users": [],
}

response = contrast.api_request(f"{args.org_id}/groups", "POST", body=body)
exit_code = 0
logger.info(" - ".join(response["messages"]))

if not response["success"]:
    logger.error("Creation failed")
    exit_code = 1

sys.exit(exit_code)
