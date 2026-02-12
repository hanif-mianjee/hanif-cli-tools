# Add new command : bumpversion | bv

I am a big fan of bump2version. Specially `.bumpversion.cfg`

Since bump2version is no longer maintained by the author, I want to create my own version with exact the same functionality with addition to more features.

Here are the additional functionality that we also need:

- Migration: `bumpversion migrate` can migrate existing version bumping config to ours. I should ask user to migrate from and provide a list of popular version bumping utilities including bump2version. After migration, delete the existing config.
- Init: Automatically detect the project like python, pyproject, react, etc. generate a config with current version of the project. Ask user if they want add files to config to also replace the verion into. Use the config template I shared below from a bump2version project
- If running direct command without any parameter or bump version, it should prompt user with options available like patch, minor, major, rc, custom, and (release option if the current version is a rc). with preview. like patch (1.0.0 → 1.0.1-rc0)
- All files mentioned in the config should automatically updated
- Before applying the next version number, verifies that the tag is not already exists. If exists, give options to users, like remove that tag from local and remove and then bump the version, or suggest +1 version, so user can decide.
- After bumping, commit the changes, create tag, and ask to push commit+tag. if users selects no, suggest command `git push --follow-tags`
- When adding our awesome new command, make it future proof. Add examples and uses in the help. Update documents. Update change log. Add tests.
- Make sure you do not break any existing functionality.
- Always use best practices. Think hard. Think like an architect.

## Config template from a bump2version project

```
[bumpversion]
current_version = 1.12.0-rc2
commit = True
tag = True
tag_name = v{new_version}
parse = (?P<major>\d+)\.(?P<minor>\d+)\.(?P<patch>\d+)([-](?P<release>(dev|rc))+(?P<rc>\d+))?
serialize = 
	{major}.{minor}.{patch}-{release}{rc}
	{major}.{minor}.{patch}

[bumpversion:part:release]
first_value = rc
optional_value = ga
values = 
	rc
	ga

[bumpversion:part:rc]
first_value = 0

[bumpversion:file:pyproject.toml]
search = version = "{current_version}"
replace = version = "{new_version}"

[bumpversion:file:generic/ingest_transform.py]
search = "{current_version}"
replace = "{new_version}"
```
