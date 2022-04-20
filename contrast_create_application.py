# Script to create an application on the Contrast TeamServer
# https://support.contrastsecurity.com/hc/en-us/articles/360060719052-How-to-create-a-custom-name-for-a-merged-group-of-Applications
# Author: josh.anderson@contrastsecurity.com

import argparse
import logging
import sys

from contrast_api import contrast_instance_from_json, load_config

args_parser = argparse.ArgumentParser(description="Create an application on Contrast.")
# Required arguments
args_parser.add_argument(
    "-n",
    "--app-name",
    "--application-name",
    help="Name of the application you want to create.",
    type=str,
    required=True,
)
args_parser.add_argument(
    "-l",
    "-language",
    help="Agent language for the application you want to create.",
    choices=["DOTNET", "DOTNET_CORE", "GO", "JAVA", "NODE", "PHP", "PYTHON", "RUBY"],
    type=str.upper,
    required=True,
)
args_parser.add_argument(
    "-o",
    "--org-id",
    "--organization-id",
    help="ID of the organization to create this application in.",
    type=str,
    required=True,
)
# Optional arguments
args_parser.add_argument(
    "-c",
    "--code",
    "--app-code",
    "--application-code",
    help="Optional 'application code' / 'short name' for this application.",
    type=str,
)
args_parser.add_argument(
    "-g",
    "--groups",
    help="Optional list of application access groups to add this application to. Group(s) must exist prior to the application for this to work.",
    type=str,
    nargs="*",
    default=[],
    action="extend",
)
args_parser.add_argument(
    "-m",
    "--metadata",
    help="Optional key/value pairs of application metadata / custom fields to set on this application.",
    type=str,
)
args_parser.add_argument(
    "-t",
    "--tags",
    help="Optional list of tags to add to this application.",
    type=str,
    nargs="*",
    default=[],
    action="extend",
)
args = args_parser.parse_args()


logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__file__)

config = load_config()
contrast = contrast_instance_from_json(config)

body = {
    "name": args.app_name,
    "language": args.l,
    "appGroups": ",".join(args.groups),
    "metadata": args.metadata,
    "tags": ",".join(args.tags),
}


response = contrast.api_request(
    f"sca/organizations/{args.org_id}/applications/create", "POST", body=body
)
exit_code = 0
logger.info(" - ".join(response["messages"]))

if not response["success"]:
    logger.error("Creation failed")
    exit_code = 1
else:
    logger.info(f"New Application ID = {response['application']['app_id']}")

sys.exit(exit_code)
