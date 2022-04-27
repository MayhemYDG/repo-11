# Script to query Contrast TeamServer to retrieve trace (vulnerability) information as csv
# Author: josh.anderson@contrastsecurity.com

import csv
import logging

from contrast_api import ContrastTeamServer, contrast_instance_from_json, load_config

# -----------------------------------#
# Some parameters for this script    #
OUTPUT_FILENAME = "./output/contrast_traces.csv"
# -----------------------------------#

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__file__)

config = load_config()
contrast = contrast_instance_from_json(config)


def format_org_traces(org, traces):
    output = []

    for trace in traces:
        output.append(
            {
                "application_name": trace["application"]["name"],
                "application_id": trace["application"]["app_id"],
                "organization_id": org[0],
                "organization_name": org[1],
                "vuln_uuid": trace["uuid"],
                "title": trace["title"],
                "type": trace["rule_title"],
                "severity": trace["severity"],
                "impact": trace["impact"],
                "confidence": trace["confidence"],
                "status": trace["status"],
                "first_time_seen": ContrastTeamServer.format_time(
                    trace["first_time_seen"]
                ),
                "last_time_seen": ContrastTeamServer.format_time(
                    trace["last_time_seen"]
                ),
                "closed_time": ContrastTeamServer.format_time(trace["closed_time"]),
            }
        )

    return output


with open(OUTPUT_FILENAME, "w", newline="") as csvfile:
    fieldnames = [
        "application_name",
        "application_id",
        "organization_id",
        "organization_name",
        "vuln_uuid",
        "title",
        "type",
        "severity",
        "confidence",
        "impact",
        "status",
        "first_time_seen",
        "last_time_seen",
        "closed_time",
    ]
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()

    orgs = contrast.list_orgs()
    for org in orgs:
        org_id = org["organization_uuid"]
        org_key = contrast.org_api_key(org_id)
        org_name = org["name"]

        if not org_key:
            logger.warning(
                f"Unable to get API Key for {org_name} -- account may not have permissions to this org. Skipping."
            )
            continue

        logger.info(f"======= Listing traces for organization: {org_name} =======")

        org_apps = contrast.list_org_apps(org_id, org_key)

        for app in org_apps:
            traces = contrast.org_traces_app(org_id, app["app_id"], org_key)

            for trace in format_org_traces((org_id, org_name), traces):
                writer.writerow(trace)


logger.info(f"Completed listing traces. Output is in {OUTPUT_FILENAME}")
