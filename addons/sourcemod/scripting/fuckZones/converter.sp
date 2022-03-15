
#if !defined _fuckZones_included
	#error You are compiling the wrong plugin, go compile fuckZones.sp
#endif

/**
 * Converts devzones into fuckZones
 *
 * @return     Amount of zones that failed to convert due to an issue, 0 on success, -1 if couldn't even get to the directory / devzones was never installed.
 */
public int ConvertZones()
{
	char Path[512];
	BuildPath(Path_SM, Path, sizeof(Path), "configs/dev_zones");

	if (!DirExists(Path))
	{
		return -1;
	}

	int iFailedCount = 0;

	DirectoryListing dir = OpenDirectory(Path);

	char sBuffer[PLATFORM_MAX_PATH];

	FileType type;
	while (dir.GetNext(sBuffer, sizeof(sBuffer), type))
	{
		if (type != FileType_File)
			continue;

		Handle kv          = CreateKeyValues("Zones");
		Handle fuckZonesKv = CreateKeyValues("zones");

		BuildPath(Path_SM, Path, sizeof(Path), "configs/dev_zones/%s", sBuffer);
		FileToKeyValues(kv, Path);

		if (!KvGotoFirstSubKey(kv))
		{
			iFailedCount++;
			continue;
		}

		char sZoneBuffer[PLATFORM_MAX_PATH];
		strcopy(sZoneBuffer, sizeof(sZoneBuffer), sBuffer);

		ReplaceString(sZoneBuffer, sizeof(sZoneBuffer), ".zones.txt", ".zon");

		char sFolder[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sFolder, sizeof(sFolder), "data/zones/");
		CreateDirectory(sFolder, 511);

		BuildPath(Path_SM, sFolder, sizeof(sFolder), "data/zones/%s", sZoneBuffer);

		FileToKeyValues(fuckZonesKv, sFolder);

		float pos1[3];
		float pos2[3];
		char  name[64];

		do
		{
			KvGetVector(kv, "cordinate_a", pos1);
			KvGetVector(kv, "cordinate_b", pos2);
			KvGetString(kv, "name", name, 64);
			int vis = KvGetNum(kv, "vis");

			KvJumpToKey(fuckZonesKv, name, true);

			KvSetVector(fuckZonesKv, "start", pos1);
			KvSetVector(fuckZonesKv, "end", pos2);
			KvSetFloat(fuckZonesKv, "radius", 150.0);
			KvSetString(fuckZonesKv, "type", "Box");
			KvSetString(fuckZonesKv, "color", "255 0 0 255");
			KvSetVector(fuckZonesKv, "teleport", view_as<float>({ 0.0, 0.0, 0.0 }));

			if (vis == 4)
				KvSetString(fuckZonesKv, "display", "Hide");

			else
				KvSetString(fuckZonesKv, "display", "Full");

			KvRewind(fuckZonesKv);
		}

		while (KvGotoNextKey(kv));

		CloseHandle(kv);

		KeyValuesToFile(fuckZonesKv, sFolder);
		delete fuckZonesKv;
	}

	delete dir;
	return iFailedCount;
}
