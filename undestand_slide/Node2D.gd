extends Node2D

var v_vel := Vector2(5,0)
var v_normal := Vector2(-1,-1).normalized() # normal
var cpt = 0

var SIZE_LENGTH = 30

func _ready() -> void:
	$CanvasLayer/TextEdit.text = String(v_vel.x) + "," + String(v_vel.y)
	$CanvasLayer/TextEdit2.text = String(v_normal.x) + "," + String(v_normal.y)
	
func _process(delta: float) -> void:
	update()
	cpt += delta
	if cpt > 5:
		cpt=0
		v_vel.y += 0.5
	
func _draw():
	draw_line(Vector2(0, -1000), Vector2(0, 1000), Color.white, 0.5)
	draw_line(Vector2(-1000, 0), Vector2(1000, 0), Color.white, 0.5)

	var v_normal_dot = v_normal * v_vel.dot(v_normal) 

	var result = v_vel.slide(v_normal)
	$CanvasLayer/Label4.text = String(result) + " normalized : " + str(result.normalized())
	$CanvasLayer/LabelMagnitude.text = "Dot vel/norm " + str(v_vel.normalized().dot(v_normal)) + " Deg " + str(rad2deg(acos(v_vel.normalized().dot(v_normal))))
	$CanvasLayer/LabelMagnitude.text += "\nDot up/normal" + str(v_vel.normalized().dot(Vector2(0, -1))) + " Deg " + str(rad2deg(acos(v_vel.normalized().dot(Vector2(0, -1)))))
	$CanvasLayer/LabelMagnitude.text += "\nmagn vel : " + str(v_vel.length()) 
	$CanvasLayer/LabelMagnitude.text += "\nmagn normal * dot " + str(v_normal_dot.length())

	draw_line(Vector2.ZERO, v_normal * SIZE_LENGTH, Color.red, 2)
	draw_line(-v_vel* SIZE_LENGTH, Vector2.ZERO, Color.green, 2)
	draw_line(Vector2.ZERO, result * SIZE_LENGTH, Color.blue, 2)


func _on_Button_pressed() -> void:
	$CanvasLayer/Label5.text = $CanvasLayer/Label4.text
	v_vel = str2var("Vector2(" + $CanvasLayer/TextEdit.text + ")")
	v_normal = str2var("Vector2(" + $CanvasLayer/TextEdit2.text + ")")
	v_normal = v_normal.normalized()

func _on_HSlider_value_changed(value: float) -> void:
	SIZE_LENGTH = value
