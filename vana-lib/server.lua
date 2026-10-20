-- vana-lib's own server side: it reads the data resources' .map files for every resource that
-- imports map_data (MapData.fileElements), as reading another resource's files takes
-- general.ModifyOtherObjects, which only vana-lib asks for (meta.xml).
function mapFileElements(resourceName)
    if type(resourceName) ~= "string" or not resourceName:find("^vana%-data%-") then return false end
    return MapData.readMapFiles(resourceName)
end
