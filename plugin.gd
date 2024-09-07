@tool
extends EditorPlugin

var plugin_name = "AIChatPlugin"

var api_key = ""
var api_url = "https://api.anthropic.com/v1/messages"

var ai_panel
var input_box
var output_label
var working_indicator

var system_prompt = """
You are an AI assistant integrated with a Godot 4.x game development project. Your role is to understand the structure and content of the project and interpret natural language requests to modify the scene. You can interact with the scene with the provided API:

API Documentation:

The API allows you to interact with the Godot project by sending JSON-formatted instructions. The JSON instructions should be provided in the following format:

{
  "thinking": "You can think through your thoughts here as much as you want. They will be ignored by the API."
  "message": "Message to the user. Concisely explain what you did.",
  "actions": [
    {
      "type": "create_node",
      "node_name": "MyNode",
      "parent_path": ".",
      "node_type": "Node2D",
      "properties": {
        "position": {
          "x": 100,
          "y": 200
        },
        "scale": {
          "x": 1.5,
          "y": 1.5
        }
      }
    },
    {
      "type": "modify_node",
      "node_path": "./MyNode",
      "properties": {
        "rotation_degrees": 45,
        "visible": false
      }
    },
    {
      "type": "create_script",
      "script_name": "MyScript",
      "node_path": "./MyNode",
      "script_content": "extends Node2D\n\nfunc _ready():\n\tprint(\"Hello, world!\")"
    },
    {
      "type": "modify_script",
      "script_path": "res://scripts/MyScript.gd",
      "script_content": "extends Node2D\n\nfunc _ready():\n\tprint(\"Hello, modified script!\")\n\nfunc my_function():\n\tprint(\"This is a new function.\")"
    },
    {
      "type": "create_resource",
      "resource_type": "Resource",
      "resource_path": "res://resources/my_resource.tres",
      "properties": {
        "property1": "value1",
        "property2": 42
      }
    },
    {
      "type": "modify_resource",
      "resource_path": "res://resources/my_resource.tres",
      "properties": {
        "property1": "new_value",
        "property3": true
      }
    },
    {
      "type": "assign_resource",
      "node_path": "./MyNode",
      "property_name": "texture",
      "resource_path": "res://assets/my_texture.png"
    }
  ]
}

The available action types are:
- "create_node": Creates a new node in the scene tree.
- "modify_node": Modifies the properties of an existing node.
- "create_script": Creates a new script file and attaches it to a node.
- "modify_script": Modifies the content of an existing script file.
- "create_resource": Creates a new resource file. Must be in res://resources
- "modify_resource": Modifies the properties of an existing resource file. Must be in res://resources
- "assign_resource": Assigns a resource to a property of a node.

You will also be provided with an overview of the current state of the project. Use this information to understand the current state of the project and generate appropriate JSON instructions to modify the project based on the user's requests. Remember that you are part of a larger system and so you should only respond with correctly formatted JSON and nothing else. Make sure to use the latest version of GDScript!
"""

var _chat_history = []
var chat_history:
    get:
        return _chat_history
    set(value):
        _chat_history = value
        output_label.text = calculate_output_label()

func calculate_output_label():
    var message = ""
    for chat in chat_history:
        var json_message = JSON.parse_string(chat["content"])["message"]
        if chat["role"] == "user":
            message += "> " + json_message + "\n"
        elif chat["role"] == "assistant":
            message += json_message + "\n"
    return message

func load_api_key(file_path: String) -> String:
    var file = FileAccess.open(file_path, FileAccess.READ)
    if file:
        var api_key = file.get_as_text().strip_edges()
        file.close()
        return api_key
    else:
        print("Failed to load API key from file: ", file_path)
        return ""

func _enter_tree():
    api_key = load_api_key("res://.api-key")
    if api_key.is_empty():
        print("API key not found in the project settings.")
        return

    print("Entering the editor tree")

    ai_panel = VBoxContainer.new()
    ai_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ai_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

    # Create an input box
    input_box = LineEdit.new()
    input_box.placeholder_text = "Enter your prompt"
    input_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    # Create an output label
    output_label = RichTextLabel.new()
    output_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

    working_indicator = Label.new()
    working_indicator.text = "Working..."
    working_indicator.visible = false

    ai_panel.add_child(output_label)
    ai_panel.add_child(working_indicator)
    ai_panel.add_child(input_box)

    # Add the input box and output label to the bottom panel
    add_control_to_bottom_panel(ai_panel, "AI Chat")

    # Connect the input box's "text_submitted" signal to a function
    input_box.text_submitted.connect(_on_input_submitted)

func _exit_tree():
    print("Exiting the editor tree")

    # Remove the input box and output label from the bottom panel
    remove_control_from_bottom_panel(ai_panel)

    # Disconnect the signal
    if input_box.is_connected("text_submitted", _on_input_submitted):
        input_box.disconnect("text_submitted", _on_input_submitted)

func _on_input_submitted(new_text):
    # Send the user's input to the API
    input_box.text = ""
    make_api_request(new_text)


    # var json_string = """
    # {
    #   "actions": [
    #     {
    #       "type": "create_node",
    #       "node_name": "MyNode",
    #       "parent_path": ".",
    #       "node_type": "Node2D",
    #       "properties": {
    #         "position": {
    #           "x": 100,
    #           "y": 200
    #         },
    #         "scale": {
    #           "x": 1.5,
    #           "y": 1.5
    #         }
    #       }
    #     },
    #     {
    #       "type": "modify_node",
    #       "node_path": "./MyNode",
    #       "properties": {
    #         "rotation_degrees": 45,
    #         "visible": false
    #       },
    #     },
    #     {
    #       "type": "create_script",
    #       "script_name": "MyScript",
    #       "node_path": "./MyNode",
    #       "script_content": "extends Node2D\n\nfunc _ready():\n\tprint(\\"Hello, world!\\")"
    #     },
    #     {
    #       "type": "modify_script",
    #       "script_path": "res://scripts/MyScript.gd",
    #       "script_content": "extends Node2D\\n\\nfunc _ready():\\n\\tprint(\\"Hello, modified script!\\")\\n\\nfunc my_function():\\n\\tprint(\\"This is a new function.\\")"
    #     }
    #   ]
    # }
    # """

func _ready():
    print("Plugin ready")
    # Add plugin setup code here
    # make_api_request("Hello, Claude!")

func _process(delta):
    # Add process code here
    pass

func _has_main_screen():
    return false

func _get_plugin_name():
    return plugin_name

func _get_plugin_icon():
    # You can return a custom icon for your plugin
    return get_editor_interface().get_base_control().get_icon("Node", "EditorIcons")

func make_api_request(prompt):
    working_indicator.visible = true

    var prompt_json = {"message": prompt, "scene_info": collect_scene_info()}
    chat_history = chat_history + [ {"role": "user", "content": JSON.stringify(prompt_json)}]

    var headers = ["Content-Type: application/json", "x-api-key: " + api_key, "anthropic-version: 2023-06-01"]
    var body = {
        "messages": chat_history,
        "model": "claude-3-5-sonnet-20240620",
        "max_tokens": 1024,
        "system": system_prompt,
    }

    var http_request = HTTPRequest.new()
    add_child(http_request)
    http_request.set_tls_options(TLSOptions.client(null, "api.anthropic.com"))
    http_request.request_completed.connect(_on_request_completed)

    var error = http_request.request("https://api.anthropic.com/v1/messages", headers, HTTPClient.METHOD_POST, JSON.stringify(body))
    if error != OK:
        push_error("API request failed: " + str(error))

func _on_request_completed(result, response_code, headers, body):
    working_indicator.visible = false
    if response_code == 200:
        var response = JSON.parse_string(body.get_string_from_utf8())
        var completion = response["content"][0]["text"]
        chat_history += [ {"role": "assistant", "content": completion}]
        print(completion)

        parse_response(completion)
    else:
        push_error("API request failed with response code: " + str(response_code))

func parse_response(response):
    var json_result = JSON.parse_string(response)

    if not json_result is Dictionary:
        print("Invalid JSON")

    var actions = json_result.get("actions", [])

    for action in actions:
        if action is Dictionary:
            var action_type = action.get("type")
            if action_type == "create_node":
                create_node(action)
            elif action_type == "modify_node":
                modify_node(action)
            elif action_type == "create_script":
                create_script(action)
            elif action_type == "modify_script":
                modify_script(action)
            elif action_type == "create_resource":
                create_resource(action)
            elif action_type == "modify_resource":
                modify_resource(action)
            elif action_type == "assign_resource":
                assign_resource(action)

func create_node(action: Dictionary):
    var node_name = action.get("node_name", "")
    var parent_path = action.get("parent_path", "")
    var node_type = action.get("node_type", "")
    var properties = action.get("properties", {})

    if node_name.is_empty() or parent_path.is_empty() or node_type.is_empty():
        print("Invalid create_node action.")
        return

    var parent_node = get_tree().get_edited_scene_root().get_node(parent_path)

    if parent_node:
        var new_node = ClassDB.instantiate(node_type)
        new_node.name = node_name
        parent_node.add_child(new_node)
        new_node.set_owner(get_tree().get_edited_scene_root())

        for property_name in properties:
            var property_value = properties[property_name]
            if property_name == "position" and property_value is Dictionary:
                new_node.position = Vector2(property_value.get("x", 0), property_value.get("y", 0))
            elif property_name == "scale" and property_value is Dictionary:
                new_node.scale = Vector2(property_value.get("x", 1), property_value.get("y", 1))
            else:
                new_node.set(property_name, property_value)

        print("Node created: ", new_node)
    else:
        print("Parent node not found: ", parent_path)


func modify_node(action: Dictionary):
    var node_path = action.get("node_path", "")
    var properties = action.get("properties", {})

    if node_path.is_empty():
        print("Invalid modify_node action.")
        return

    var node = get_tree().get_edited_scene_root().get_node(node_path)
    if node:
        for property_name in properties:
            var property_value = properties[property_name]
            if property_name == "position" and property_value is Dictionary:
                node.position = Vector2(property_value.get("x", 0), property_value.get("y", 0))
            elif property_name == "scale" and property_value is Dictionary:
                node.scale = Vector2(property_value.get("x", 1), property_value.get("y", 1))
            else:
                node.set(property_name, property_value)

        print("Node modified: ", node)
    else:
        print("Node not found: ", node_path)


func create_script(action: Dictionary):
    var script_name = action.get("script_name", "")
    var node_path = action.get("node_path", "")
    var script_content = action.get("script_content", "")

    if script_name.is_empty() or node_path.is_empty() or script_content.is_empty():
        print("Invalid create_script action.")
        return

    var node = get_tree().get_edited_scene_root().get_node(node_path)
    if node:
        var script_path = "res://scripts/" + script_name + ".gd"
        var script_directory = script_path.get_base_dir()

        # Create the directory if it doesn't exist
        var directory = DirAccess.open("res://")
        if not directory.dir_exists(script_directory):
            directory.make_dir_recursive(script_directory)

        # Save the script content to a file
        var file = FileAccess.open(script_path, FileAccess.WRITE)
        if file:
            file.store_string(script_content)
            file.close()

            # Load the script from the file and attach it to the node
            var script = load(script_path)
            if script is GDScript:
                node.set_script(script)
                print("Script created and attached to node: ", node)
            else:
                print("Failed to load the script.")
        else:
            print("Failed to create the script file.")
    else:
        print("Node not found: ", node_path)

func modify_script(action: Dictionary):
    var script_path = action.get("script_path", "")
    var script_content = action.get("script_content", "")

    if script_path.is_empty() or script_content.is_empty():
        print("Invalid modify_script action.")
        return

    var file = FileAccess.open(script_path, FileAccess.READ)
    if file:
        file.close()

        # Update the script content
        file = FileAccess.open(script_path, FileAccess.WRITE)
        if file:
            file.store_string(script_content)
            file.close()

            # Reload the script
            var script = load(script_path)
            if script is GDScript:
                script.reload()
                print("Script modified: ", script_path)
            else:
                print("Failed to reload the script.")
        else:
            print("Failed to open the script file for writing.")
    else:
        print("Script file not found: ", script_path)

func create_resource(action: Dictionary):
    var resource_type = action.get("resource_type", "")
    var resource_path = action.get("resource_path", "")
    var properties = action.get("properties", {})

    if resource_type.is_empty() or resource_path.is_empty():
        print("Invalid create_resource action.")
        return

    if not resource_path.begins_with("res://resources"):
        print("Invalid resource access.")
        return

    var resource = ClassDB.instantiate(resource_type)
    if resource:
        for property_name in properties:
            var property_value = properties[property_name]
            resource.set(property_name, property_value)

        var error = ResourceSaver.save(resource, resource_path)
        if error == OK:
            print("Resource created: ", resource_path)
        else:
            print("Failed to save the resource: ", resource_path)
    else:
        print("Invalid resource type: ", resource_type)

func modify_resource(action: Dictionary):
    var resource_path = action.get("resource_path", "")
    var properties = action.get("properties", {})

    if not resource_path.begins_with("res://resources"):
        print("Invalid resource access.")
        return

    if resource_path.is_empty():
        print("Invalid modify_resource action.")
        return

    var resource = load(resource_path)
    if resource:
        for property_name in properties:
            var property_value = properties[property_name]
            resource.set(property_name, property_value)

        var error = ResourceSaver.save(resource, resource_path)
        if error == OK:
            print("Resource modified: ", resource_path)
        else:
            print("Failed to save the modified resource: ", resource_path)
    else:
        print("Resource not found: ", resource_path)

func assign_resource(action: Dictionary):
    var node_path = action.get("node_path", "")
    var property_name = action.get("property_name", "")
    var resource_path = action.get("resource_path", "")

    if node_path.is_empty() or property_name.is_empty() or resource_path.is_empty():
        print("Invalid assign_resource action.")
        return

    var node = get_tree().get_edited_scene_root().get_node(node_path)
    if node:
        var resource = load(resource_path)
        if resource:
            node.set(property_name, resource)
            print("Resource assigned to node: ", node_path)
        else:
            print("Resource not found: ", resource_path)
    else:
        print("Node not found: ", node_path)

func collect_scene_info() -> Dictionary:
    var scene_info = {}

    # Collect asset information
    var asset_info = []
    var asset_files = _find_asset_files("res://assets")
    for asset_file in asset_files:
        var asset_data = {
            "path": asset_file,
        }
        asset_info.append(asset_data)
    scene_info["assets"] = asset_info

    # Collect resource information
    var resource_info = []
    var resource_files = _find_asset_files("res://resources")
    for resource_file in resource_files:
        var resource_data = {
            "path": resource_file,
        }
        resource_info.append(resource_data)
    scene_info["resources"] = resource_info

    # Collect scene tree information
    var tree_info = _collect_tree_info(get_tree().get_edited_scene_root())
    scene_info["scene_tree"] = tree_info

    return scene_info

func _find_asset_files(path: String) -> Array:
    var asset_files = []
    var directory = DirAccess.open(path)
    if directory:
        directory.list_dir_begin()
        var file_name = directory.get_next()
        while file_name != "":
            if not directory.current_is_dir():
                    asset_files.append(path + file_name)
            else:
                if file_name != "." and file_name != "..":
                    asset_files += _find_asset_files(path + file_name + "/")
            file_name = directory.get_next()
    return asset_files

func _collect_tree_info(node: Node, level: int = 0) -> Dictionary:
    var node_info = {
        "name": node.name,
        "type": node.get_class(),
        "children": []
    }

    # Collect script information for the node
    if node.get_script():
        node_info["script"] = {
            "path": node.get_script().resource_path,
            "content": node.get_script().source_code
        }

    # Collect information about the node's children recursively
    for child in node.get_children():
        node_info["children"].append(_collect_tree_info(child, level + 1))

    return node_info
