package main

import "core:math/linalg"
import "core:math/rand"
import "core:math/big"
import "core:strconv"
import "core:strings"
import "core:fmt"
import "vendor:raylib"

Game :: struct {
    state: GameState,
    kind: GameKind
}

GameState :: enum {
    MainMenu,
    MultiplayerMenu,
    InGame,
    PauseMenu
}

GameKind :: enum {
    SinglePlayer,
    LocalMultiplayer,
    OnlineMultiplayer
}

Kind :: enum {
    Bounding,
    Left,
    Right,
    Ball,
    Player
}

Result :: union {
    raylib.Vector2,
    string
}

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
    kind: Kind,
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
    object: Object,
    points: int
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

physics_update :: proc(engine: ^PhysicsEngine) -> (bool, string) {
    for id, &object in engine.rigid_bodies {
        result := check_collisions(engine, id, object)
        vector, ok := result.(raylib.Vector2)
        if ok {
            object.actual_speed = vector
            object.position += object.actual_speed * raylib.GetFrameTime()
            update_real_position(&engine.host_info, &object.position, &object.real_position)
        }else{
            return true, result.(string)
        }
    }
    return false, ""
}

draw_ball_speed :: proc(host_info: ^HostInfo, ball: ^Ball) {
    xbuffer : [10]u8
    ybuffer : [10]u8
    total_buffer : [10]u8
    xspeed := strconv.ftoa(xbuffer[:], f64(ball.object.actual_speed.x), 'f', 2, 64)
    yspeed := strconv.ftoa(ybuffer[:], f64(ball.object.actual_speed.y), 'f', 2, 64)
    total_speed := strconv.ftoa(total_buffer[:], f64(linalg.length(ball.object.actual_speed)), 'f', 2, 64)
    speed, _ := strings.join({"[", xspeed, " ",  yspeed, "] ", total_speed}, "")
    raylib.DrawText(strings.clone_to_cstring(speed), i32(host_info.space_unit.x * 40), i32(host_info.space_unit.x * 3), i32(host_info.space_unit.x * 2), raylib.WHITE)
}

helper :: proc(collided: bool, object: ^Object, other_object: ^Object, other_id: i32, host_info: HostInfo) -> raylib.Vector2 {
    if object.kind == Kind.Bounding {
        return {0.0, 0.0}
    }
    is_colliding, is_ok := object.collision_set[other_id]
    rec, ok := other_object.shape.(Box)
    if object.kind == Kind.Ball && other_object.kind == Kind.Player && ok {
        vector := (object.real_position - (other_object.real_position + {0.0, rec.rectangle.height / 2}))
        angle := linalg.angle_between(other_object.real_position + {0.0, rec.rectangle.height / 2}, object.real_position)
        raylib.DrawLineV(object.real_position, other_object.real_position + {0.0, rec.rectangle.height / 2}, raylib.LIME)
        raylib.DrawLineV(object.real_position, object.real_position + vector, raylib.BROWN)
        raylib.DrawLineV(object.real_position, object.real_position + object.actual_speed, raylib.PINK)
    }
    if !is_ok {
        if collided && other_object.kind == Kind.Player {
            map_insert(&object.collision_set, other_id, Empty{})
            angle := linalg.angle_between(other_object.real_position + {0.0, rec.rectangle.height / 2}, object.real_position)
            vector := (object.real_position - (other_object.real_position + {0.0, rec.rectangle.height / 2}))
            rotated := raylib.Vector2Rotate(vector, 0.0)
            fmt.println(linalg.normalize(rotated) * 75)
            return linalg.normalize(([2]f32){rotated.x, -rotated.y})
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

draw_points :: proc(host_info: ^HostInfo, player_one, player_two: ^Player) {
    buffer : [10]u8
    buffer_two : [10]u8
    fmt.println(player_one.points, player_two.points)
    val_one := strconv.itoa(buffer[:], player_one.points)
    val_two := strconv.itoa(buffer_two[:], player_two.points)
    raylib.DrawText(strings.clone_to_cstring(val_one), i32(host_info.space_unit.x * 5), i32(host_info.space_unit.y * 3), i32(host_info.space_unit.x * 7), raylib.WHITE)
    raylib.DrawText(strings.clone_to_cstring(val_two), i32(host_info.space_unit.x * 90), i32(host_info.space_unit.y * 3), i32(host_info.space_unit.x * 7), raylib.WHITE)
}

check_collisions :: proc(engine: ^PhysicsEngine, id: i32, object: ^Object) -> Result {
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
                if collided && other_object.kind == Kind.Left {
                    return "two"
                }
                if collided && other_object.kind == Kind.Right {
                    return "one"
                }
            case Sphere:
                collided = raylib.CheckCollisionCircles(object.real_position, object_sphere.radius, other_object.real_position, shape.radius)
            }
            rtn += helper(collided, object, other_object, other_id, engine.host_info)
        }
    }
    if rtn == {0.0, 0.0} {
        return object.actual_speed
    }
    return linalg.normalize(rtn) * linalg.length(object.actual_speed)
}

reset_game :: proc(host_info: ^HostInfo, player_one, player_two: ^Player, ball: ^Ball, which: string) {
    player_one_points := player_one.points
    player_two_points := player_two.points
    player_one^ = create_player_one(host_info)
    player_two^ = create_player_two(host_info)
    ball^ = create_ball(host_info)
    if which == "one" {
        player_one.points += 1
    }else{
        player_two.points += 1
    }
    player_one.points += player_one_points
    player_two.points += player_two_points
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
    game := Game {
        GameState.MainMenu,
        GameKind.SinglePlayer
    }
    x := raylib.GetScreenWidth()
    y := raylib.GetScreenHeight()
    raylib.InitWindow(x, y, "Hello, Raylib!")
    raylib.ToggleFullscreen()
    host_info := create_host_info()
    raylib.SetTargetFPS(60)
    defer raylib.CloseWindow()
    camera := create_2d_camera()
    raylib.BeginMode2D(camera)
    for !raylib.WindowShouldClose() {
        #partial switch game.state {
            case .MainMenu:
            draw_menu(&host_info, &game)
            case .InGame:
            gameloop(&host_info, &game)
        }
    }
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
            Kind.Player,
            make(map[i32]Empty)
        },
        0
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

gameloop :: proc(host_info: ^HostInfo, game: ^Game) {
    engine := new_physics(host_info^)
    boundings := create_boundings(host_info)
    object := Object {
        {0, 0},
        Sphere {
            0.0
        },
        {0.0, 0.0},
        {0.0, 0.0},
        Kind.Bounding,
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
            Kind.Bounding,
            make(map[i32]Empty)
        }
        if i == 0 {
            objects[i].kind = Kind.Left
        }
        if i == 2 {
            objects[i].kind = Kind.Right
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
        if body.kind == Kind.Bounding || body.kind == Kind.Left || body.kind == Kind.Right {
            nboundings[count] = body
            count += 1
        }
    }
    for !raylib.WindowShouldClose() {
        raylib.BeginDrawing()
        raylib.ClearBackground(raylib.BLACK)
        if raylib.IsWindowResized() {
            resize_things(host_info, &player_one, &player_two, nboundings, &ball)
        }
        if raylib.IsKeyPressed(raylib.KeyboardKey.ENTER) {
            game.state = GameState.MainMenu
            raylib.EndDrawing()
            return
        }
        result, which := physics_update(&engine)
        if result {
            reset_game(host_info, &player_one, &player_two, &ball, which)
        }
        fmt.println(result)
        draw_ball_speed(host_info, &ball)
        move_players(host_info, &player_one, &player_two, game, &ball)
        draw_points(&engine.host_info, &player_one, &player_two)
        draw_player(&player_one)
        draw_player(&player_two)
        draw_ball(&ball)
        draw_boundings(host_info, nboundings)
        raylib.EndDrawing()
        if raylib.IsKeyPressed(raylib.KeyboardKey.ENTER) {
            game.state = GameState.MainMenu
        }
    }
}

draw_ball :: proc(ball: ^Ball) {
    raylib.DrawCircleV(ball.object.real_position, ball.object.shape.(Sphere).radius * 0.75, ball.color)
}

move_players :: proc(host_info: ^HostInfo, player_one, player_two: ^Player, game: ^Game, ball: ^Ball) {
    #partial switch game.kind {
        case .SinglePlayer:
        movement_vector := read_input(player_one.input_map)
        move(host_info, player_one, &movement_vector)
        update_real_position(host_info, &player_one.object.position, &player_one.object.real_position)
        movement_vector = calculate_cpu_movement(player_two, ball)
        move(host_info, player_two, &movement_vector)
        update_real_position(host_info, &player_two.object.position, &player_two.object.real_position)
    case .LocalMultiplayer:
        movement_vector := read_input(player_one.input_map)
        move(host_info, player_one, &movement_vector)
        update_real_position(host_info, &player_one.object.position, &player_two.object.real_position)
        movement_vector = read_input(player_two.input_map)
        move(host_info, player_two, &movement_vector)
        update_real_position(host_info, &player_two.object.position, &player_two.object.real_position)
    }
}

calculate_cpu_movement :: proc(player: ^Player, ball: ^Ball) -> raylib.Vector2 {
    distance := ball.object.position - player.object.position
    distance.x = 0
    return linalg.normalize(distance)
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
            Kind.Ball,
            make(map[i32]Empty)
        }
    }
}
draw_menu :: proc(host_info: ^HostInfo, game: ^Game) {
    raylib.BeginDrawing()
    font_size := host_info.space_unit.x * 3
    title := "Pong Fodase"
    raylib.DrawText(strings.clone_to_cstring(title), i32(host_info.space_unit.x * 50) - i32(font_size) * i32(i32(len(title)) / 3), i32(host_info.space_unit.y * 10), i32(font_size), raylib.RED)
    if raylib.GuiButton(create_rectangle(host_info, {30, 5}, {50 - 15, 50}), "Local Multiplayer") {
        game.state = GameState.InGame
        game.kind = GameKind.LocalMultiplayer
    }
    if raylib.GuiButton(create_rectangle(host_info, {30, 5}, {50 - 15, 60}), "Single Player") {
        game.state = GameState.InGame
        game.kind = GameKind.SinglePlayer
    }
    raylib.GuiButton(create_rectangle(host_info, {30, 5}, {50 - 15, 55}), "Online Multiplayer")
    raylib.EndDrawing()
}

create_rectangle :: proc(host_info: ^HostInfo, size, position: raylib.Vector2) -> raylib.Rectangle {
    real_position := host_info.space_unit * position
    real_size := host_info.space_unit * size
    return raylib.Rectangle {
        real_position.x,
        real_position.y,
        real_size.x,
        real_size.y
    }
}
