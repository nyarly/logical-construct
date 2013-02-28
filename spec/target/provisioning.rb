#Notes for the moment:
#
#Server has a "status service" - RESTful on 51076
#Target provisioning can PUT /needs path=<path> sig=<sig> role=<role>
#Then there's a GET /needs/<path> -> "role, sig, resolved/unresolved"
#GC provisioning can POST to /needs/<path> file=<file>
#  Rejected with 409 unless MAC aligns with <sig>
#
#Also /resolved-needs and /unresolved-needs
#And /provisioning-status
#  GET /provisioning-status includes:
#    Current stage of deployment (waiting for target, target started, waiting
#    for provisioning needs, performing provision, complete)
#    Last query (if any) to /resolved_needs
#    Link to provisioning log
#  PUT /provisioning-status updates "current stage"
#all navigable from /
#
#
#Manifest Resolution responsible for removing outdated files from
#<dir>/provision-files
