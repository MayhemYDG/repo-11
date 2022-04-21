# Script toset the status of Contrast vulnerabilities, with an optional comment
# Author: josh.anderson@contrastsecurity.com

import argparse
import logging
import sys

from contrast_api import contrast_instance_from_json, load_config

substatus_mappings = {
    "FP": "False Positive",
    "EC": "Attack is defended by an external control",
    "SC": "Goes through an internal security control",
    "OT": "Other",
    "URL": "URL is only accessible by trusted power users",
}

args_parser = argparse.ArgumentParser(
    description="Set the status of Contrast vulnerabilities with an optional comment."
)
# Required arguments
args_parser.add_argument(
    "-t",
    "--trace-id",
    help="ID(s) of the trace(s) you want to update.",
    type=str,
    nargs="*",
    required=True,
    action="extend",
)
args_parser.add_argument(
    "-s",
    "--status",
    help="Status to mark these vulnerabilities.",
    choices=[
        "Reported",
        "Suspicious",
        "Confirmed",
        "NotAProblem",
        "Remediated",
        "Fixed",
    ],
    type=str,
    required=True,
)
args_parser.add_argument(
    "-b",
    "--sub-status",
    help=f"Substatus to mark these vulnerabilities when using NotAProblem. Allowed values: {substatus_mappings}",
    choices=substatus_mappings.keys(),
    type=str,
)
args_parser.add_argument(
    "-o",
    "--org-id",
    "--organization-id",
    help="ID of the organization with the trace(s).",
    type=str,
    required=True,
)
# Optional arguments
args_parser.add_argument(
    "-m",
    "--message",
    "--explanation",
    help="Optional comment to add to these vulnerabilities with the status change.",
    type=str,
)
args = args_parser.parse_args()


logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
logger = logging.getLogger(__file__)

config = load_config()
contrast = contrast_instance_from_json(config)

body = {
    "traces": args.trace_id,
    "status": args.status,
    "note": args.message,
}

response = contrast.api_request(f"{args.org_id}/orgtraces/mark", "PUT", body=body)
exit_code = 0
logger.info(" - ".join(response["messages"]))

if not response["success"]:
    logger.error("Mark vulnerabilities failed")
    exit_code = 1

sys.exit(exit_code)
