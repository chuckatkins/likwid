#!<INSTALLED_BINPREFIX>/likwid-lua
--[[
 * =======================================================================================
 *
 *      Filename:  likwid-setFrequencies.lua
 *
 *      Description:  A application to set the CPU frequency of CPU cores and domains.
 *
 *      Version:   <VERSION>
 *      Released:  <DATE>
 *
 *      Author:   Thomas Roehl (tr), thomas.roehl@gmail.com
 *      Project:  likwid
 *
 *      Copyright (C) 2016 RRZE, University Erlangen-Nuremberg
 *
 *      This program is free software: you can redistribute it and/or modify it under
 *      the terms of the GNU General Public License as published by the Free Software
 *      Foundation, either version 3 of the License, or (at your option) any later
 *      version.
 *
 *      This program is distributed in the hope that it will be useful, but WITHOUT ANY
 *      WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
 *      PARTICULAR PURPOSE.  See the GNU General Public License for more details.
 *
 *      You should have received a copy of the GNU General Public License along with
 *      this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * =======================================================================================
]]

package.path = '<INSTALLED_PREFIX>/share/lua/?.lua;' .. package.path

local likwid = require("likwid")

print_stdout = print
print_stderr = function(...) for k,v in pairs({...}) do io.stderr:write(v .. "\n") end end

sys_base_path = "/sys/devices/system/cpu"
set_command = "<INSTALLED_PREFIX>/sbin/likwid-setFreq"


function version()
    print_stdout(string.format("likwid-setFrequencies --  Version %d.%d",likwid.version,likwid.release))
end

function usage()
    version()
    print_stdout("A tool to adjust frequencies and governors on x86 CPUs.\n")
    print_stdout("Options:")
    print_stdout("-h\t Help message")
    print_stdout("-v\t Version information")
    print_stdout("-c dom\t Likwid thread domain which to apply settings (default are all CPUs)")
    print_stdout("\t See likwid-pin -h for details")
    print_stdout("-g gov\t Set governor (" .. table.concat(likwid.getAvailGovs(nil), ", ") .. ") (set to ondemand if omitted)")
    print_stdout("-f/--freq freq\t Set current frequency, implicitly sets userspace governor")
    print_stdout("-x/--min freq\t Set minimal frequency")
    print_stdout("-y/--max freq\t Set maximal frequency")
    print_stdout("-p\t Print current frequencies")
    print_stdout("-l\t List available frequencies")
    print_stdout("-m\t List available governors")
end

--[[function getCurrentMinFreq(cpuid)
    local min = 10000000
    if cpuid == nil or cpuid < 0 then
        for cpuid=0,topo["numHWThreads"]-1 do
            fp = io.open(sys_base_path .. "/" .. string.format("cpu%d",cpuid) .. "/cpufreq/scaling_min_freq")
            if verbosity == 3 then
                print_stdout("Reading "..sys_base_path .. "/" .. string.format("cpu%d",cpuid) .. "/cpufreq/scaling_min_freq" )
            end
            line = fp:read("*l")
            if tonumber(line)/1E6 < min then
                min = tonumber(line)/1E6
            end
            fp:close()
        end
    else
        fp = io.open(sys_base_path .. "/" .. string.format("cpu%d",cpuid) .. "/cpufreq/scaling_min_freq")
        if verbosity == 3 then
            print_stdout("Reading "..sys_base_path .. "/" .. string.format("cpu%d",cpuid) .. "/cpufreq/scaling_min_freq" )
        end
        line = fp:read("*l")
        if tonumber(line)/1E6 < min then
            min = tonumber(line)/1E6
        end
        fp:close()
    end
    return min
end

function getCurrentMaxFreq(cpuid)
    local max = 0
    if cpuid == nil or cpuid < 0 then
        for cpuid=0,topo["numHWThreads"]-1 do
            fp = io.open(sys_base_path .. "/" .. string.format("cpu%d",cpuid) .. "/cpufreq/scaling_max_freq")
            if verbosity == 3 then
                print_stdout("Reading "..sys_base_path .. "/" .. string.format("cpu%d",cpuid) .. "/cpufreq/scaling_max_freq" )
            end
            line = fp:read("*l")
            if tonumber(line)/1E6 > max then
                max = tonumber(line)/1E6
            end
            fp:close()
        end
    else
        fp = io.open(sys_base_path .. "/" .. string.format("cpu%d",cpuid) .. "/cpufreq/scaling_max_freq")
        if verbosity == 3 then
            print_stdout("Reading "..sys_base_path .. "/" .. string.format("cpu%d",cpuid) .. "/cpufreq/scaling_max_freq" )
        end
        line = fp:read("*l")
        if tonumber(line)/1E6 > max then
            max = tonumber(line)/1E6
        end
        fp:close()
    end
    return max
end


function getAvailFreq(cpuid)
    if cpuid == nil then
        cpuid = 0
    end
    if cpuid < 0 then
        cpuid = 0
    end
    fp = io.open(sys_base_path .. "/" .. string.format("cpu%d",cpuid) .. "/cpufreq/scaling_available_frequencies")
    if verbosity == 3 then
        print_stdout("Reading "..sys_base_path .. "/" .. string.format("cpu%d",cpuid) .. "/cpufreq/scaling_available_frequencies" )
    end
    line = fp:read("*l")
    fp:close()
    local tmp = likwid.stringsplit(line:gsub("^%s*(.-)%s*$", "%1"), " ", nil, " ")
    local avail = {}
    local turbo = tonumber(tmp[1])/1E6
    local j = 1
    for i=2,#tmp do
        local freq = tonumber(tmp[i])/1E6
        avail[j] = tostring(freq)
        if not avail[j]:match("%d+.%d+") then
            avail[j] = avail[j] ..".0"
        end
        j = j + 1
    end
    if verbosity == 1 then
        print_stdout(string.format("The system provides %d scaling frequencies, frequency %s is taken as turbo mode", #avail,turbo))
    end
    return avail, tostring(turbo)
end

function getCurFreq()
    local freqs = {}
    local govs = {}
    for cpuid=0,topo["numHWThreads"]-1 do
        local fp = io.open(sys_base_path .. "/" .. string.format("cpu%d",cpuid) .. "/cpufreq/scaling_cur_freq")
        if verbosity == 3 then
            print_stdout("Reading "..sys_base_path .. "/" .. string.format("cpu%d",cpuid) .. "/cpufreq/scaling_cur_freq" )
        end
        local line = fp:read("*l")
        fp:close()
        freqs[cpuid] = tostring(tonumber(line)/1E6)
        if not freqs[cpuid]:match("%d.%d") then
            freqs[cpuid] = freqs[cpuid] ..".0"
        end
        local fp = io.open(sys_base_path .. "/" .. string.format("cpu%d",cpuid) .. "/cpufreq/scaling_governor")
        if verbosity == 3 then
            print_stdout("Reading "..sys_base_path .. "/" .. string.format("cpu%d",cpuid) .. "/cpufreq/scaling_governor" )
        end
        local line = fp:read("*l")
        fp:close()
        govs[cpuid] = line
    end
    return freqs, govs
end

function getAvailGovs(cpuid)
    if (cpuid == nil) or (cpuid < 1) then
        cpuid = 0
    end
    local fp = io.open(sys_base_path .. "/" .. string.format("cpu%d",cpuid) .. "/cpufreq/scaling_available_governors")
    if verbosity == 3 then
        print_stdout("Reading "..sys_base_path .. "/" .. string.format("cpu%d",cpuid) .. "/cpufreq/scaling_available_governors" )
    end
    local line = fp:read("*l")
    fp:close()
    local avail = likwid.stringsplit(line:gsub("^%s*(.-)%s*$", "%1"), "%s+", nil, "%s+")
    for i=1,#avail do
        if avail[i] == "userspace" then
            table.remove(avail, i)
            break
        end
    end
    table.insert(avail, "turbo")
    if verbosity == 1 then
        print_stdout(string.format("The system provides %d scaling governors", #avail))
    end
    return avail
end

local function testDriver()
    local fp = io.open(sys_base_path .. "/" .. string.format("cpu%d",0) .. "/cpufreq/scaling_driver")
    if verbosity == 3 then
        print_stdout("Reading "..sys_base_path .. "/" .. string.format("cpu%d",0) .. "/cpufreq/scaling_driver" )
    end
    local line = fp:read("*l")
    fp:close()
    if line == "acpi-cpufreq" then
        return true
    end
    return false
end]]

verbosity = 0
governor = nil
frequency = nil
min_freq = nil
max_freq = nil
domain = nil
printCurFreq = false
printAvailFreq = false
printAvailGovs = false

if #arg == 0 then
    usage()
    os.exit(0)
end


for opt,arg in likwid.getopt(arg, {"g:", "c:", "f:", "l", "p", "h", "v", "m", "x:", "y:", "help","version","freq:", "min:", "max:"}) do
    if opt == "h" or opt == "help" then
        usage()
        os.exit(0)
    elseif opt == "v" or opt == "version" then
        version()
        os.exit(0)
    elseif (opt == "c") then
        domain = arg
    elseif (opt == "g") then
        governor = arg
    elseif opt == "f" or opt == "freq" then
        frequency = arg
    elseif opt == "x" or opt == "min" then
        min_freq = arg
    elseif opt == "y" or opt == "max" then
        max_freq = arg
    elseif (opt == "p") then
        printCurFreq = true
    elseif (opt == "l") then
        printAvailFreq = true
    elseif (opt == "m") then
        printAvailGovs = true
    elseif opt == "?" then
        print_stderr("Invalid commandline option -"..arg)
        os.exit(1)
    elseif opt == "!" then
        print_stderr("Option requires an argument")
        os.exit(1)
    end
end
if likwid.getDriver() ~= "acpi-cpufreq" then
    print_stderr("The system does not use the acpi-cpufreq driver, other drivers are not usable with likwid-setFrequencies.")
    os.exit(1)
end

topo = likwid.getCpuTopology()
affinity = likwid.getAffinityInfo()
if not domain or domain == "N" then
    domain = "N:0-" .. tostring(topo["numHWThreads"]-1)
end
if domain:match("[SCM]%d") then
    for i, dom in pairs(affinity["domains"]) do
        if dom["tag"]:match(domain) then
            domain = domain..":0-"..tostring(dom["numberOfProcessors"]-1)
        end
    end
end
cpulist = {}
numthreads, cpulist = likwid.cpustr_to_cpulist(domain)
if verbosity == 3 then
    print_stdout(string.format("Given CPU expression expands to %d CPU cores:", numthreads))
    local str = tostring(cpulist[1])
    for i=2, numthreads  do
        str = str .. "," .. tostring(cpulist[i])
    end
    print_stdout(str)
end


if printAvailGovs then
    local govs = likwid.getAvailGovs(0)
    print_stdout("Available governors:")
    print_stdout(string.format("%s %s", table.concat(govs, " "), "turbo"))
end

if printAvailFreq then
    local freqs, turbo = likwid.getAvailFreq(0)
    print_stdout("Available frequencies:")
    print_stdout(string.format("%s %s", turbo, table.concat(freqs, " ")))
end

if printCurFreq then
    print_stdout("Current frequencies:")
    for i=1,#cpulist do
        gov = likwid.getGovernor(cpulist[i])
        freq = tonumber(likwid.getCpuClockCurrent(cpulist[i]))/1E9
        min = tonumber(likwid.getCpuClockMin(cpulist[i]))/1E9
        max = tonumber(likwid.getCpuClockMax(cpulist[i]))/1E9
        print_stdout(string.format("CPU %d: governor %12s min/cur/max %s/%s/%s GHz",cpulist[i], gov, min, freq, max))
    end
end

if printAvailGovs or printAvailFreq or printCurFreq then
    os.exit(0)
end

if numthreads > 0 and not (frequency or min_freq or max_freq or governor) then
    print_stderr("ERROR: You need to set either a frequency or governor for the selected CPUs on commandline")
    os.exit(1)
end

if min_freq and max_freq and min_freq > max_freq then
    print_stderr("ERROR: Minimal frequency higher than maximal frequency.")
    os.exit(1)
end
if min_freq and max_freq and max_freq < min_freq then
    print_stderr("ERROR: Maximal frequency below than minimal frequency.")
    os.exit(1)
end


local availfreqs, availturbo = likwid.getAvailFreq(cpulist[i])

if min_freq then
    for i=1,#cpulist do
        local valid_freq = false
        for k,v in pairs(availfreqs) do
            if (min_freq == v) then
                valid_freq = true
                break
            end
        end
        if min_freq == turbo then
            valid_freq = true
        end
        if not valid_freq then
            print_stderr(string.format("ERROR: Frequency %s not available for CPU %d! Please select one of\n%s", min_freq, cpulist[i], table.concat(availfreqs, ", ")))
            os.exit(1)
        end
        local f = likwid.setCpuClockMin(cpulist[i], tonumber(min_freq)*1E6)
    end
end

if max_freq then
    for i=1,#cpulist do
        local valid_freq = false
        for k,v in pairs(availfreqs) do
            if (max_freq == v) then
                valid_freq = true
                break
            end
        end
        if max_freq == turbo then
            valid_freq = true
        end
        if not valid_freq then
            print_stderr(string.format("ERROR: Frequency %s not available for CPU %d! Please select one of\n%s", max_freq, cpulist[i], table.concat(availfreqs, ", ")))
            os.exit(1)
        end
        local f = likwid.setCpuClockMax(cpulist[i], tonumber(max_freq)*1E6)
    end
end

if frequency then
    for i=1,#cpulist do
        
        local valid_freq = false
        for k,v in pairs(availfreqs) do
            if (frequency == v) then
                valid_freq = true
                break
            end
        end
        if frequency == turbo then
            valid_freq = true
        end
        if not valid_freq then
            print_stderr(string.format("ERROR: Frequency %s not available for CPU %d! Please select one of\n%s", frequency, cpulist[i], table.concat(availfreqs, ", ")))
            os.exit(1)
        end
        local f = likwid.setCpuClockCurrent(cpulist[i], tonumber(frequency)*1E6)
    end
end

if governor then
    local govs = likwid.getAvailGovs(cpulist[1])
    local cur_govs = {}
    for i,c in pairs(cpulist) do
        table.insert(cur_govs, likwid.getGovernor(cpulist[1]))
    end
    
    local valid_gov = false
    for k,v in pairs(govs) do
        if (governor == v) then
            valid_gov = true
            break
        end
    end
    if governor == "turbo" and turbo ~= "0" then
        valid_gov = true
        for i=1,#cpulist do
            cur_freqs[cpulist[i]] = turbo
        end
    end
    if not valid_gov then
        print_stderr(string.format("ERROR: Governor %s not available! Please select one of\n%s", governor, table.concat(govs, ", ")))
        os.exit(1)
    end
    for i=1,#cpulist do
        if governor ~= cur_govs[i] then
            local f = likwid.setGovernor(cpulist[i], governor)
        end
    end
end
likwid.putAffinityInfo()
likwid.putTopology()
os.exit(0)
