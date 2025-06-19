local currentThread = nil

local function executeCallback(callback, ...)
    local previousThread = currentThread
    currentThread = nil
    callback(...)
    currentThread = previousThread
end

local function coroutineHandler()
    while true do
        executeCallback(coroutine.yield())
    end
end

local signalConnection = {}
signalConnection.__index = signalConnection

function signalConnection.new(signal, callback)
    assert(type(signal) == "table", "Signal must be a table")
    assert(type(callback) == "function", "Callback must be a function")
    return setmetatable({
        ClassName = "SignalConnection",
        _connected = true,
        _signal = signal,
        _callback = callback,
        _next = nil
    }, signalConnection)
end

function signalConnection:Disconnect()
    self._connected = false
    if self._signal._handlerListHead == self then
        self._signal._handlerListHead = self._next
    else
        local prev = self._signal._handlerListHead
        while prev and prev._next ~= self do
            prev = prev._next
        end
        if prev then
            prev._next = self._next
        end
    end
end

local signal = {}
signal.__index = signal

function signal.new()
    return setmetatable({
        ClassName = "Signal",
        _handlerListHead = nil,
        _enabled = true
    }, signal)
end

function signal:Destroy()
    self:DisconnectAll()
    self:Disable()
    setmetatable(self, nil)
    table.clear(self)
end

function signal:Disable()
    self._enabled = false
end

function signal:Enable()
    self._enabled = true
end

function signal:Connect(callback)
    assert(type(callback) == "function", "Callback must be a function")
    local connection = signalConnection.new(self, callback)
    if not self._handlerListHead then
        self._handlerListHead = connection
    else
        connection._next = self._handlerListHead
        self._handlerListHead = connection
    end
    return connection
end

function signal:DisconnectAll()
    self._handlerListHead = nil
end

function signal:Fire(...)
    if self._enabled then
        local handler = self._handlerListHead
        while handler do
            if handler._connected then
                if not currentThread then
                    currentThread = coroutine.create(coroutineHandler)
                    coroutine.resume(currentThread)
                end
                task.spawn(currentThread, handler._callback, ...)
            end
            handler = handler._next
        end
    end
end

function signal:Wait()
    local waitingCoroutine = coroutine.running()
    local capturedArguments = nil
    local connection; connection = self:Connect(function(...)
        connection:Disconnect()
        capturedArguments = table.pack(...)
        task.spawn(waitingCoroutine, ...)
    end)
    coroutine.yield()
    return table.unpack(capturedArguments)
end

function signal:Once(callback)
    assert(type(callback) == "function", "Callback must be a function")
    local connection; connection = self:Connect(function(...)
        if connection._connected then
            connection:Disconnect()
        end
        callback(...)
    end)
    return connection
end

return signal
