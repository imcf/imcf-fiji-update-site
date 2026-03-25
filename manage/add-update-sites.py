#@ AppService app
#@ File sites_collection

# pylint: disable-msg=import-error
# pylint: disable-msg=missing-docstring
# pylint: disable-msg=invalid-name
# pylint: disable-msg=undefined-variable
# pylint: disable-msg=used-before-assignment

# Wrapper script to activate a list of update sites in ImageJ defined in a JSON
# file as a name-value mapping ("Site-Name":"URI"). To use it launch ImageJ in
# a fashion like this:
#
# ImageJ-linux64 --ij2 --headless --console \
#     --run /path/to/add-update-sites.py \
#     "sites_collection='/path/to/update-site-list.json'"

import json
import re

from net.imagej.updater import FilesCollection


def add_update_site(collection, name, uri):
    """Wrapper to add and activate an update site to Fiji.

    Parameters
    ----------
    collection : net.imagej.updater.FilesCollection
        A FilesCollection object representing the ImageJ base directory.
    name : str
        The name of the update site to be added.
    uri : str
        The URI of the update site to be added.
    """
    newSite = collection.addUpdateSite(name, uri, None, None, 0)
    collection.addUpdateSite(newSite)
    newSite.setActive(True)
    print "Enabled Update Site '%s'  [%s]" % (name, uri)

def parseJsonc(json_file):
        return json.loads("".join(re.split(r"[ \t]\/\/.*", json_file.read())).strip())

sites_collection = str(sites_collection)
print "Reading update sites from [%s]" % sites_collection
with open(sites_collection) as infile:
    update_sites = parseJsonc(infile)

imagejDir = app.getApp().getBaseDirectory()
ijFilesCollection = FilesCollection(imagejDir)
ijFilesCollection.read()

for site in update_sites:
    add_update_site(ijFilesCollection, site, update_sites[site])

ijFilesCollection.markForUpdate(True)
ijFilesCollection.write()

print "\nEnabled update sites:\n%s" % ijFilesCollection.getUpdateSiteNames()
