-- Runs one scene at a time. A scene is a table with update(), which handles a frame's input and
-- drawing, and optionally enter(...), exit(), save(), and pause(). SceneManager.onSwitch, if set, is called with
-- the new scene after each switch.

SceneManager = {}

local currentScene

function SceneManager.switch(scene, ...)
    if currentScene and currentScene.exit then currentScene.exit() end
    currentScene = scene
    if scene.enter then scene.enter(...) end
    if SceneManager.onSwitch then SceneManager.onSwitch(scene) end
end

function SceneManager.update() currentScene.update() end

function SceneManager.save()
    if currentScene and currentScene.save then currentScene.save() end
end

function SceneManager.pause()
    SceneManager.save()
    if currentScene and currentScene.pause then currentScene.pause() end
end

function SceneManager.isCurrent(scene) return currentScene == scene end
