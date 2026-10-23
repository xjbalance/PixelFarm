class_name SeasonalDialogue
extends RefCounted
const LINES := {
	"linya":["春土回暖了。我把去年的种袋摊开，能用的留着，不能急着全换新。","夏天收菜要早些。车还没来，我们可以先把遮阳棚支好。","秋天的收据分两份，一份给送菜的人，一份留在共仓。","冬天先种耐寒小麦吧。胡萝卜和土豆留在田里休眠，不用拔掉。"],
	"zhou":["木头过完冬要再量一次。我今天检查檐角，你过桥时看看新水线。","太阳落下前得收好工具。热起来后，旧铁件也会松动。","叶子落进排水口了。清出来不显眼，可明年会省很多力气。","雪盖住了路边的石头，我把木作坊门口扫开，过来时慢一点。"],
	"ahe":["窗台的第一盆花开了。留言册不用换新本，旧页后面还有空白。","茶凉得慢。我多放了几个杯子，忙完的人都能坐一会儿。","有人把第一穗麦夹在留言册里。它压得不平，却很舍不得拿走。","冬天门口容易结霜。想聊一会儿就进檐下，我会把灯留着。"],
	"xiaojing":["我想先记下水草长出来的位置，再和旧地图比一比。","晚上看星星前，我得把今天的水样送回去。到时你有空，就一起。","温室旁的叶子我留了两片，一片压进笔记，另一片还给风。","这几天我在整理温室里的记录。雪落得很安静，正适合把缺的那一行补上。"]
}
static func line(person: String) -> String:
	if not LINES.has(person): return ""
	var text: String=LINES[person][Calendar.season()]
	if GameWeather.is_snowy(): text+="\n积雪不会替农田浇水，路标也别被雪埋住了。"
	elif GameWeather.is_harsh(): text+="\n天气重了些，我们先在檐下把今天的事安排好。"
	elif GameWeather.is_rainy(): text+="\n雨会浇透露天田，鱼栏也能接到一点新水。"
	elif GameWeather.weather_id()=="fog": text+="\n河岸有雾，顺着旧路标走，别为了抄近路下水。"
	elif GameWeather.is_meteor_night(): text+="\n今晚有流星。记得在午夜前把要做的事收好。"
	return text
