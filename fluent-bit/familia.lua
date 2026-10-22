-- Funções Lua usadas pelo fluent-bit.conf

local function trim_nl(s)
  if type(s) ~= "string" then return s end
  return (s:gsub("[\r\n]+$", ""))
end

local function safe(s)
  return (tostring(s):gsub("[^%w_%-]", "-"))
end

-- docker.raw: {log, stream, attrs{labels swarm}, file} -> registro limpo
function docker_extract(tag, timestamp, record)
  local service, task = "unknown", nil
  local attrs = record["attrs"]
  if type(attrs) == "table" then
    local name = attrs["com.docker.swarm.service.name"]
    local ns   = attrs["com.docker.stack.namespace"]
    task       = attrs["com.docker.swarm.task.name"]
    if name then
      -- "familia-connect_front" -> "front"
      if ns and name:sub(1, #ns + 1) == ns .. "_" then
        name = name:sub(#ns + 2)
      end
      service = safe(name)
    end
  end

  local new = {
    service = service,
    task    = task,
    stream  = record["stream"],
    message = trim_nl(record["log"]),
  }
  local f = record["file"]
  if type(f) == "string" then
    local id = f:match("/containers/(%x+)/")
    if id then new["container_id"] = id:sub(1, 12) end
  end
  return 2, timestamp, new
end

-- Todos os registros: envelope padrão (ts, category, source, message)
function finalize(tag, timestamp, record)
  -- journald (systemd input): converte campos MAIÚSCULOS
  if record["MESSAGE"] ~= nil then
    record = {
      host     = record["host"],
      role     = record["role"],
      message  = record["MESSAGE"],
      unit     = record["_SYSTEMD_UNIT"],
      priority = record["PRIORITY"],
      program  = record["SYSLOG_IDENTIFIER"],
      pid      = record["_PID"],
    }
  end

  local category, source = tag:match("^([^.]+)%.(.+)$")
  record["category"] = category or "unknown"
  record["source"]   = source or "unknown"

  local sec = math.floor(timestamp["sec"])
  local ms  = math.floor((timestamp["nsec"] or 0) / 1000000)
  record["ts"] = os.date("!%Y-%m-%dT%H:%M:%S", sec) .. string.format(".%03dZ", ms)

  record["message"] = trim_nl(record["message"])
  return 2, timestamp, record
end
