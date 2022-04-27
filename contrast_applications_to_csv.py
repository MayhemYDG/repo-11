# Script to query Contrast TeamServer to retrieve application information as csv
# Author: josh.anderson@contrastsecurity.com

import csv
import logging

from contrast_api import ContrastTeamServer, contrast_instance_from_json, load_config

# -----------------------------------#
# Some parameters for this script    #
OUTPUT_FILENAME = "./output/contrast_apps.csv"
INCLUDE_MERGED = True
INCLUDE_ARCHIVED = False
# Names of custom application metadata fields to include in the output
APPLICATION_METADATA_FIELDS = ["custom_field_name1", "custom_field_name2"]
# -----------------------------------#

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__file__)

config = load_config()
contrast = contrast_instance_from_json(config)


def format_apps(apps, org):
    output = []
    for application in apps:
        routes = application.get("routes", {})
        # extract application metadata fields to a (name:value) dictionary
        metadata = {
            entry["fieldName"]: entry["fieldValue"]
            for entry in application["metadataEntities"]
        }

        output.append(
            {
                "application_name": application["name"],
                "application_id": application["app_id"],
                "application_code": application["short_name"],
                "parent_application_id": application.get("parentApplicationId"),
                "archived": application["archived"],
                **{
                    f"metadata_{key}": metadata.get(key)
                    for key in APPLICATION_METADATA_FIELDS
                },
                "license": application["license"]["level"],
                "organization_id": org[0],
                "organization_name": org[1],
                "score": application["scores"]["letter_grade"],
                "language": application["language"],
                "created": ContrastTeamServer.format_time(application["created"]),
                "last_seen": ContrastTeamServer.format_time(application["last_seen"]),
                "tags": ", ".join(application["tags"]),
                "total_modules": application["total_modules"],
                "routes_discovered": routes.get("discovered", 0),
                "routes_exercised": routes.get("exercised", 0),
            }
        )

    return output


with open(OUTPUT_FILENAME, "w", newline="") as csvfile:
    fieldnames = [
        "application_name",
        "application_id",
        "application_code",
        "parent_application_id",
        "archived",
        *list((f"metadata_{key}") for key in APPLICATION_METADATA_FIELDS),
        "license",
        "score",
        "organization_id",
        "organization_name",
        "language",
        "created",
        "last_seen",
        "tags",
        "total_modules",
        "routes_discovered",
        "routes_exercised",
    ]
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()

    # list all organizations and loop through them
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

        # list all applications in this organization
        logger.info(f"======= Listing apps for organization: {org_name} ======")
        apps = contrast.list_org_apps(
            org_id,
            org_key,
            include_merged=INCLUDE_MERGED,
            include_archived=INCLUDE_ARCHIVED,
        )

        for app in format_apps(apps, (org_id, org_name)):
            writer.writerow(app)

    logger.info("Completed listing applications. Output is in " + OUTPUT_FILENAME)
