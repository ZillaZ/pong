package main

import "core:math/linalg"
import "core:math/rand"
import "core:math/big"
import "core:fmt"
import "vendor:raylib"

Empty :: struct {}

Sphere :: struct {
    radius: f32
}

Box :: struct {
    rectangle: raylib.Rectangle
}

Shape :: union {
    Sphere,
    Box
}

Object :: struct {
    position: raylib.Vector2,
    shape: Shape,
    actual_speed: raylib.Vector2,
    real_position: raylib.Vector2,
    name: string,
    collision_set: map[i32]Empty
}

PhysicsEngine :: struct {
    rigid_bodies: map[i32]^Object,
    host_info: HostInfo
}

Boundings :: struct {
    border_size: raylib.Vector2,
    border_color: raylib.Color
}

Player :: struct {
    speed: f32,
    input_map: map[raylib.KeyboardKey]raylib.Vector2,
    object: Object
}

Ball :: struct {
    color: raylib.Color,
    speed: f32,
    object: Object
}

HostInfo :: struct {
    window_size: [2]f32,
    space_unit: [2]f32
}

Collision :: struct {
    point: raylib.Vector2,
    angle: f32,
    total_speed: f32
}

new_physics :: proc(host_info: HostInfo) -> PhysicsEngine {
    return PhysicsEngine {
        make(map[i32]^Object),
        host_info
    }
}

physics_update :: proc(engine: ^PhysicsEngine) {
    for id, &object in engine.rigid_bodies {
        vector := check_collisions(engine, id, object)
        object.actual_speed = vector
        object.position += object.actual_speed * raylib.GetFrameTime()
        update_real_position(&engine.host_info, &object.position, &object.real_position)
    }
}

helper :: proc(collided: bool, object: ^Object, other_object: ^Object, other_id: i32, host_info: HostInfo) -> raylib.Vector2{
    if object.name == "Bounding" {
        return {0.0, 0.0}
    }
    is_colliding, is_ok := object.collision_set[other_id]
    rec, ok := other_object.shape.(Box)
    if object.name == "Ball" && other_object.name == "Player" && ok {
        vector := (object.real_position - (other_object.real_position + {0.0, rec.rectangle.height / 2}))
        angle := linalg.angle_between(other_object.real_position + {0.0, rec.rectangle.height / 2}, object.real_position)
        raylib.DrawLineV(object.real_position, other_object.real_position + {0.0, rec.rectangle.height / 2}, raylib.LIME)
        raylib.DrawLineV(object.real_position, object.real_position + vector, raylib.BROWN)
        raylib.DrawLineV(object.real_position, object.real_position + object.actual_speed, raylib.PINK)
    }
    if !is_ok {
        if collided && other_object.name == "Player" {
            map_insert(&object.collision_set, other_id, Empty{})
            angle := linalg.angle_between(other_object.real_position + {0.0, rec.rectangle.height / 2}, object.real_position)
            vector := (object.real_position - (other_object.real_position + {0.0, rec.rectangle.height / 2}))
            rotated := raylib.Vector2Rotate(vector, 0.0)
            fmt.println(linalg.normalize(rotated) * 75)
            return linalg.normalize(([2]f32){rotated.x, -rotated.y}) * host_info.space_unit * 5
        }else if collided {
            return object.actual_speed * {1.0, -1.0}
        }
    }else{
        if !collided {
            delete_key(&object.collision_set, other_id)
        }
    }
    return raylib.Vector2(0.0)
}

check_collisions :: proc(engine: ^PhysicsEngine, id: i32, object: ^Object) -> raylib.Vector2 {
    object_box, ok := object.shape.(Box)
    object_sphere, _ := object.shape.(Sphere)
    rtn : [2]f32 = {0.0, 0.0}
    if ok {
        for other_id, other_object in engine.rigid_bodies {
            if id == other_id {continue}
            collided := false
            switch shape in other_object.shape {
            case Box:
                collided = raylib.CheckCollisionRecs(object_box.rectangle, shape.rectangle)
            case Sphere:
                collided = raylib.CheckCollisionCircleRec(other_object.real_position, shape.radius, object_box.rectangle)
            }
            rtn += helper(collided, object, other_object, other_id, engine.host_info)
        }
    }else{
        for other_id, other_object in engine.rigid_bodies {
            if id == other_id {continue}
            collided := false
            switch shape in other_object.shape {
            case Box:
                collided = raylib.CheckCollisionCircleRec(object.real_position, object_sphere.radius, shape.rectangle)
            case Sphere:
                collided = raylib.CheckCollisionCircles(object.real_position, object_sphere.radius, other_object.real_position, shape.radius)
            }
            rtn += helper(collided, object, other_object, other_id, engine.host_info)
        }
    }
    if linalg.length(rtn) < 1.0 {
        return object.actual_speed
    }
    return rtn
}

create_host_info :: proc() -> HostInfo {
    window_size : [2]f32 = {cast(f32)raylib.GetScreenWidth(), cast(f32)raylib.GetScreenHeight()}
    space_unit : [2]f32 = {window_size.x / 100.0, window_size.y / 100.0}
    return HostInfo {
        window_size,
        space_unit
    }
}

main :: proc() {
    x := raylib.GetScreenWidth()
    y := raylib.GetScreenHeight()
    raylib.InitWindow(x, y, "Hello, Raylib!")
    raylib.ToggleFullscreen()
    host_info := create_host_info()
    raylib.SetTargetFPS(60)
    defer raylib.CloseWindow()
    camera := create_2d_camera()
    raylib.BeginMode2D(camera)
    gameloop(&host_info)
}

create_boundings :: proc(host_info: ^HostInfo) -> [4]raylib.Rectangle {
    left_bounding := raylib.Rectangle {
        host_info.space_unit.x * 10,
        host_info.space_unit.y * 10,
        host_info.space_unit.x,
        host_info.space_unit.y * 80
    }
    upper_bounding := raylib.Rectangle {
        host_info.space_unit.x * 10,
        host_info.space_unit.y * 10,
        host_info.space_unit.x * 80,
        host_info.space_unit.y
    }
    right_bounding := raylib.Rectangle {
        host_info.space_unit.x * 90,
        host_info.space_unit.y * 10,
        host_info.space_unit.x,
        host_info.space_unit.y * 80
    }
    bottom_bounding := raylib.Rectangle {
        host_info.space_unit.x * 10,
        host_info.space_unit.y * 90,
        host_info.space_unit.x * 80,
        host_info.space_unit.y
    }
    return {left_bounding, upper_bounding, right_bounding, bottom_bounding}
}

create_player :: proc(host_info: ^HostInfo, position: raylib.Vector2, input_map: map[raylib.KeyboardKey]raylib.Vector2) -> Player {
    size := host_info.space_unit * {1.0, 15}
    real_position := host_info.space_unit * position
    real_position.y -= size.y / 2
    return Player {
        50.0,
        input_map,
        Object {
            position - {0.0, 7.5},
            Box {
                raylib.Rectangle {
                    real_position.x,
                    real_position.y,
                    size.x,
                    size.y
                }
            },
            {0.0, 0.0},
            real_position,
            "Player",
            make(map[i32]Empty)
        }
    }
}

create_2d_camera :: proc() -> raylib.Camera2D {
    return raylib.Camera2D {
        offset = {0, 0},
        target = {0, 0},
        rotation = 0,
        zoom = 0
    }
}

create_player_one :: proc(host_info: ^HostInfo) -> Player {
    input_one := make(map[raylib.KeyboardKey]raylib.Vector2)
    map_insert(&input_one, raylib.KeyboardKey.W, raylib.Vector2({0.0, -1.0}))
    map_insert(&input_one, raylib.KeyboardKey.S, raylib.Vector2({0.0, 1.0}))
    return create_player(host_info, raylib.Vector2({15.0, 50.0}), input_one)
}

create_player_two :: proc(host_info: ^HostInfo) -> Player {
    input_two := make(map[raylib.KeyboardKey]raylib.Vector2)
    map_insert(&input_two, raylib.KeyboardKey.UP, raylib.Vector2({0.0, -1.0}))
    map_insert(&input_two, raylib.KeyboardKey.DOWN, raylib.Vector2({0.0, 1.0}))
    return create_player(host_info, raylib.Vector2({85.0, 50.0}), input_two)
}

add_object :: proc(engine: ^PhysicsEngine, object: ^Object) {
    map_insert(&engine.rigid_bodies, rand.int31(), object)
}

gameloop :: proc(host_info: ^HostInfo) {
    engine := new_physics(host_info^)
    boundings := create_boundings(host_info)
    object := Object {
        {0, 0},
        Sphere {
            0.0
        },
        {0.0, 0.0},
        {0.0, 0.0},
        "dummy",
        make(map[i32]Empty)
    }
    objects : [4]Object = {object, object, object, object}
    for bounding, i in boundings {
        objects[i] = Object {
            ({bounding.x, bounding.y} / host_info.space_unit),
            Box {
                bounding
            },
            {0.0, 0.0},
            {bounding.x, bounding.y},
            "Bounding",
            make(map[i32]Empty)
        }
        add_object(&engine, &objects[i])
    }
    player_one := create_player_one(host_info)
    player_two := create_player_two(host_info)
    ball := create_ball(host_info)
    add_object(&engine, &player_one.object)
    add_object(&engine, &player_two.object)
    add_object(&engine, &ball.object)
    nboundings : [4]^Object
    count := 0
    for _, body in &engine.rigid_bodies {
        if body.name == "Bounding" {
            nboundings[count] = body
            count += 1
        }
    }
    for !raylib.WindowShouldClose() {
        if raylib.IsWindowResized() {
            resize_things(host_info, &player_one, &player_two, nboundings, &ball)
        }
        physics_update(&engine)
        move_player(host_info, &player_one)
        move_player(host_info, &player_two)
        raylib.BeginDrawing()
        draw_player(&player_one)
        draw_player(&player_two)
        draw_ball(&ball)
        draw_boundings(host_info, nboundings)
        raylib.ClearBackground(raylib.BLACK)
        raylib.EndDrawing()
    }
}

draw_ball :: proc(ball: ^Ball) {
    raylib.DrawCircleV(ball.object.real_position, ball.object.shape.(Sphere).radius * 0.75, ball.color)
}

move_player :: proc(host_info: ^HostInfo, player: ^Player) {
    movement_vector := read_input(player.input_map)
    move(host_info, player, &movement_vector)
    update_real_position(host_info, &player.object.position, &player.object.real_position)
}

draw_player :: proc(player: ^Player) {
    raylib.DrawRectangleRec(player.object.shape.(Box).rectangle, raylib.WHITE)
}

draw_boundings :: proc(host_info: ^HostInfo, boundings: [4]^Object) {
    for bounding in boundings {
        raylib.DrawRectangleRec(bounding.shape.(Box).rectangle, raylib.GOLD)
    }
}

resize_things :: proc(host_info: ^HostInfo, player_one: ^Player, player_two: ^Player, boundings: [4]^Object, ball: ^Ball) {
    helper := host_info^
    host_info^ = create_host_info()
    resize_boundings(helper, host_info, boundings)
    resize_player(host_info, player_one)
    resize_player(host_info, player_two)
    resize_ball(helper, host_info, ball)
}

resize_ball :: proc(old: HostInfo, host_info: ^HostInfo, ball: ^Ball) {
    ball.object.real_position = ball.object.position * host_info.space_unit
    ball.speed = host_info.space_unit.x * 5
    shape := &ball.object.shape.(Sphere)
    ball.object.actual_speed = (ball.object.actual_speed / old.space_unit) * host_info.space_unit
    shape^ = Sphere {
        host_info.space_unit.x * 2
    }
}

resize_boundings :: proc(old: HostInfo, host_info: ^HostInfo, boundings: [4]^Object) {
    for object in boundings {
        object.real_position = host_info.space_unit * object.position
        box, ok := &object.shape.(Box)
        if ok {
            box.rectangle = raylib.Rectangle {
                object.real_position.x,
                object.real_position.y,
                (box.rectangle.width / old.space_unit.x) * host_info.space_unit.x,
                (box.rectangle.height / old.space_unit.y) * host_info.space_unit.y
            }
        }
    }
}

resize_player :: proc(host_info: ^HostInfo, player: ^Player) {
    size := host_info.space_unit * {1.0, 15}
    player.object.real_position = host_info.space_unit * player.object.position
    rec := &player.object.shape.(Box)
    rec.rectangle = raylib.Rectangle {
        player.object.real_position.x,
        player.object.real_position.y,
        size.x,
        size.y
    }
}

read_input :: proc(input_map: map[raylib.KeyboardKey]raylib.Vector2) -> raylib.Vector2 {
    movement_vector := raylib.Vector2(0)
    for keycode, vector in input_map {
        if !raylib.IsKeyDown(keycode) {continue}
        movement_vector += vector
    }
    return raylib.Vector2Normalize(movement_vector)
}

move :: proc(host_info: ^HostInfo, player: ^Player, movement_vector: ^raylib.Vector2) {
    movement_vector^ *= player.speed * raylib.GetFrameTime()
    player.object.position += (movement_vector^)
    update_real_position(host_info, &player.object.position, &player.object.real_position)
    rec := &player.object.shape.(Box)
    rec.rectangle = raylib.Rectangle {
        player.object.real_position.x,
        player.object.real_position.y,
        rec.rectangle.width,
        rec.rectangle.height
    }
}

update_real_position :: proc(host_info: ^HostInfo, position: ^raylib.Vector2, real_position: ^raylib.Vector2) {
    real_position^ = host_info.space_unit * (position^)
}

create_ball :: proc(host_info: ^HostInfo) -> Ball {
    radius := host_info.space_unit.x * 2.0
    position : [2]f32 = {50.0, 50.0}
    real_position := host_info.space_unit * position
    return Ball {
        raylib.RED,
        host_info.space_unit.x * 10,
        Object{
            position,
            Sphere {
                radius
            },
            {host_info.space_unit.x * 5, 0.0},
            real_position,
            "Ball",
            make(map[i32]Empty)
        }
    }
}
