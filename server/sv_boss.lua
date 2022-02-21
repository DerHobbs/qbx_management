local QBCore = exports['qb-core']:GetCoreObject()
local Accounts = {}

CreateThread(function()
	Wait(500)
	local bossmenu = MySQL.Sync.fetchAll('SELECT * FROM okokbanking_societies', {})
	if not bossmenu then
		return
	end
	for k,v in pairs(bossmenu) do
		local k = tostring(v.society)
		local v = tonumber(v.value)
		if k and v then
			Accounts[k] = v
		end
	end
end)

RegisterNetEvent("qb-bossmenu:server:addAccountMoney", function(account, amount)
	local account2 = 'society_'..account
	if not Accounts[account2] then
		Accounts[account2] = 0
	end

	Accounts[account2] = Accounts[account2] + amount

	MySQL.Async.execute('UPDATE okokbanking_societies SET value = ? WHERE society = ?', { Accounts[account2], account2 })
end)

RegisterNetEvent("qb-bossmenu:server:removeAccountMoney", function(account, amount)
	local account2 = 'society_'..account
	if not Accounts[account2] then
		Accounts[account2] = 0
	end

	if Accounts[account2] >= amount then
		Accounts[account2] = Accounts[account2] - amount
	end

	MySQL.Async.execute('UPDATE okokbanking_societies SET value = ? WHERE society = ?', { Accounts[account2], account2 })
end)

RegisterNetEvent('qb-bossmenu:server:updateBalance', function(account, amount, typet)
	if not Accounts[account] then
		Accounts[account] = 0
	end

	if typet then
		Accounts[account] = Accounts[account] + amount
	else
		if Accounts[account] >= amount then
			Accounts[account] = Accounts[account] - amount
		end
	end
end)

QBCore.Functions.CreateCallback('qb-bossmenu:server:GetAccount', function(source, cb, jobname)
	local result = GetAccount(jobname)
	cb(result)
end)

-- Export
function GetAccount(account)
	local account2 = 'society_'..account
	return Accounts[account2] or 0
end

-- Get Employees
QBCore.Functions.CreateCallback('qb-bossmenu:server:GetEmployees', function(source, cb, jobname)
	local src = source
	local employees = {}
	if not Accounts[jobname] then
		Accounts[jobname] = 0
	end
	local players = MySQL.Sync.fetchAll("SELECT * FROM `players` WHERE `job` LIKE '%".. jobname .."%'", {})
	if players[1] ~= nil then
		for key, value in pairs(players) do
			local isOnline = QBCore.Functions.GetPlayerByCitizenId(value.citizenid)

			if isOnline then
				employees[#employees+1] = {
				empSource = isOnline.PlayerData.citizenid,
				grade = isOnline.PlayerData.job.grade,
				isboss = isOnline.PlayerData.job.isboss,
				name = '🟢' .. isOnline.PlayerData.charinfo.firstname .. ' ' .. isOnline.PlayerData.charinfo.lastname
				}
			else
				employees[#employees+1] = {
				empSource = value.citizenid,
				grade =  json.decode(value.job).grade,
				isboss = json.decode(value.job).isboss,
				name = '❌' ..  json.decode(value.charinfo).firstname .. ' ' .. json.decode(value.charinfo).lastname
				}
			end
		end
	end
	cb(employees)
end)

-- Grade Change
RegisterNetEvent('qb-bossmenu:server:GradeUpdate', function(data)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local Employee = QBCore.Functions.GetPlayerByCitizenId(data.cid)
	if Employee then
		if Employee.Functions.SetJob(Player.PlayerData.job.name, data.grado) then
			TriggerClientEvent('QBCore:Notify', src, "Successfully promoted!", "success")
			TriggerClientEvent('QBCore:Notify', Employee.PlayerData.source, "You have been promoted to" ..data.nomegrado..".", "success")
		else
			TriggerClientEvent('QBCore:Notify', src, "Promotion grade does not exist.", "error")
		end
	else
		TriggerClientEvent('QBCore:Notify', src, "Civilian not in city.", "error")
	end
	TriggerClientEvent('qb-bossmenu:client:OpenMenu', src)
end)

-- Fire Employee
RegisterNetEvent('qb-bossmenu:server:FireEmployee', function(target)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local Employee = QBCore.Functions.GetPlayerByCitizenId(target)
	if Employee then
		if Employee.Functions.SetJob("unemployed", '0') then
			TriggerEvent("qb-log:server:CreateLog", "bossmenu", "Job Fire", "red", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname .. ' successfully fired ' .. Employee.PlayerData.charinfo.firstname .. " " .. Employee.PlayerData.charinfo.lastname .. " (" .. Player.PlayerData.job.name .. ")", false)
			TriggerClientEvent('QBCore:Notify', src, "Employee fired!", "success")
			TriggerClientEvent('QBCore:Notify', Employee.PlayerData.source , "You have been fired! Good luck.", "error")
			MySQL.Async.execute('DELETE FROM player_jobs WHERE cid = ? AND job = ?', {Employee.PlayerData.citizenid, Player.PlayerData.job.name})
		else
			TriggerClientEvent('QBCore:Notify', src, "Error..", "error")
		end
	else
		local player = MySQL.Sync.fetchAll('SELECT * FROM players WHERE citizenid = ? LIMIT 1', { target })
		if player[1] ~= nil then
			Employee = player[1]
			local job = {}
			job.name = "unemployed"
			job.label = "Unemployed"
			job.payment = 500
			job.onduty = true
			job.isboss = false
			job.grade = {}
			job.grade.name = nil
			job.grade.level = 0
			MySQL.Async.execute('UPDATE players SET job = ? WHERE citizenid = ?', { json.encode(job), target })
			MySQL.Async.execute('DELETE FROM player_jobs WHERE cid = ? AND job = ?', {Employee.PlayerData.citizenid, Player.PlayerData.job.name})
			TriggerClientEvent('QBCore:Notify', src, "Employee fired!", "success")
			TriggerEvent("qb-log:server:CreateLog", "bossmenu", "Job Fire", "red", Player.PlayerData.charinfo.firstname .. " " .. Player.PlayerData.charinfo.lastname .. ' successfully fired ' .. Employee.PlayerData.charinfo.firstname .. " " .. Employee.PlayerData.charinfo.lastname .. " (" .. Player.PlayerData.job.name .. ")", false)
		else
			TriggerClientEvent('QBCore:Notify', src, "Civilian not in city.", "error")
		end
	end
	TriggerClientEvent('qb-bossmenu:client:OpenMenu', src)
end)

-- Recruit Player
RegisterNetEvent('qb-bossmenu:server:HireEmployee', function(recruit)
	local src = source
	local Player = QBCore.Functions.GetPlayer(src)
	local Target = QBCore.Functions.GetPlayer(recruit)
	if Player.PlayerData.job.isboss == true then
		if Target and Target.Functions.SetJob(Player.PlayerData.job.name, 0) then
			TriggerClientEvent('QBCore:Notify', src, "You hired " .. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. " come " .. Player.PlayerData.job.label .. "", "success")
			TriggerClientEvent('QBCore:Notify', Target.PlayerData.source , "You were hired as " .. Player.PlayerData.job.label .. "", "success")
			TriggerEvent('qb-log:server:CreateLog', 'bossmenu', 'Recruit', "lightgreen", (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname).. " successfully recruited " .. (Target.PlayerData.charinfo.firstname .. ' ' .. Target.PlayerData.charinfo.lastname) .. ' (' .. Player.PlayerData.job.name .. ')', false)
		end
	end
	TriggerClientEvent('qb-bossmenu:client:OpenMenu', src)
end)

-- Get closest player sv
QBCore.Functions.CreateCallback('qb-bossmenu:getplayers', function(source, cb)
	local src = source
	local players = {}
	local PlayerPed = GetPlayerPed(src)
	local pCoords = GetEntityCoords(PlayerPed)
	for k, v in pairs(QBCore.Functions.GetPlayers()) do
		local targetped = GetPlayerPed(v)
		local tCoords = GetEntityCoords(targetped)
		local dist = #(pCoords - tCoords)
		if PlayerPed ~= targetped and dist < 10 then
			local ped = QBCore.Functions.GetPlayer(v)
			players[#players+1] = {
			id = v,
			coords = GetEntityCoords(targetped),
			name = ped.PlayerData.charinfo.firstname .. " " .. ped.PlayerData.charinfo.lastname,
			citizenid = ped.PlayerData.citizenid,
			sources = GetPlayerPed(ped.PlayerData.source),
			sourceplayer = ped.PlayerData.source
			}
		end
	end
		table.sort(players, function(a, b)
			return a.name < b.name
		end)
	cb(players)
end)
