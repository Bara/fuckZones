#if defined _zones_manager_stocks_included
    #endinput
#endif
#define _zones_manager_stocks_included

stock bool IsClientValid(int client)
{
	if (client > 0 && client <= MaxClients)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client))
		{
			return true;
		}
	}
	return false;
}

stock bool AreVectorsEqual(const float vec1[3], const float vec2[3])
{
	return vec1[0] == vec2[0] && vec1[1] == vec2[1] && vec1[2] == vec2[2];
}

stock void CopyArrayToArray(const any[] array, any[] newArray, int size)
{
	for (int i = 0; i < size; i++)
	{
		newArray[i] = array[i];
	}
}

stock void FillArrayToValue(any[] array, int size, any value, int start = 0)
{
	if (start < 0)
	{
		start = 0;
	}

	for (int i = start; i < size; i++)
	{
		array[i] = value;
	}
}

//SM9(); has molested this stock at this point. <3
stock void GetAbsBoundingBox(int ent, float mins[3], float maxs[3], bool half = false)
{
    float origin[3];

    GetEntPropVector(ent, Prop_Data, "m_vecAbsOrigin", origin);
    GetEntPropVector(ent, Prop_Data, "m_vecMins", mins);
    GetEntPropVector(ent, Prop_Data, "m_vecMaxs", maxs);

    mins[0] += origin[0];
    mins[1] += origin[1];
    mins[2] += origin[2];
    maxs[0] += origin[0];
    maxs[1] += origin[1];
    
    if (!half) {
        maxs[2] += origin[2];
    } else {
        maxs[2] = mins[2];
    }
}

stock void Effect_DrawBeamBoxToClient(int client, const float bottomCorner[3], const float upperCorner[3], int modelIndex, int haloIndex, int startFrame = 0, int frameRate = 30, float life = 5.0, float width = 5.0, float endWidth = 5.0, int fadeLength = 2, float amplitude = 1.0, const color[4] =  { 255, 0, 0, 255 }, int speed = 0)
{
	int clients[1];
	clients[0] = client;
	Effect_DrawBeamBox(clients, 1, bottomCorner, upperCorner, modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
}

stock void Effect_DrawBeamBox(int[] clients, int numClients, const float bottomCorner[3], const float upperCorner[3], int modelIndex, int haloIndex, int startFrame = 0, int frameRate = 30, float life = 5.0, float width = 5.0, float endWidth = 5.0, int fadeLength = 2, float amplitude = 1.0, const color[4] =  { 255, 0, 0, 255 }, int speed = 0)
{
	float corners[8][3];

	for (int i = 0; i < 4; i++)
	{
		CopyArrayToArray(bottomCorner, corners[i], 3);
		CopyArrayToArray(upperCorner, corners[i + 4], 3);
	}

	corners[1][0] = upperCorner[0];
	corners[2][0] = upperCorner[0];
	corners[2][1] = upperCorner[1];
	corners[3][1] = upperCorner[1];
	corners[4][0] = bottomCorner[0];
	corners[4][1] = bottomCorner[1];
	corners[5][1] = bottomCorner[1];
	corners[7][0] = bottomCorner[0];

	for (int i = 0; i < 4; i++)
	{
		int j = (i == 3 ? 0 : i + 1);
		TE_SetupBeamPoints(corners[i], corners[j], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_Send(clients, numClients);
	}

	for (int i = 4; i < 8; i++)
	{
		int j = (i == 7 ? 4 : i + 1);
		TE_SetupBeamPoints(corners[i], corners[j], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_Send(clients, numClients);
	}

	for (int i = 0; i < 4; i++)
	{
		TE_SetupBeamPoints(corners[i], corners[i + 4], modelIndex, haloIndex, startFrame, frameRate, life, width, endWidth, fadeLength, amplitude, color, speed);
		TE_Send(clients, numClients);
	}
}
