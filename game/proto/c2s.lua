.package {
	type 0 : integer
	session 1 : integer
	msg 2 : string
}

.login {
	uid 0 : integer
	ip 1 : string
	logintime 2 : integer
	lasttime 3 : integer
}

.item{
	id 0:integer
	num 1:integer
}

.equipment_prop{ #装备属性值
    id 0:integer
    value 1:double
    num_type 2:integer
}

.gem{
    id 0:integer    
    uuid 1:integer
    lv 2: integer
    exp 3 : integer
    equip_id 4 : integer   
}

.equipment{
	id 0:integer
	uuid 1:integer
	on 2:boolean
    init_prop 4:*equipment_prop
    lv 5 : integer
    deify_lv 6 : integer
    inlay_list 7 :*integer
    recover_num 8 : integer
}

.citta{
	id 0:integer	
	uuid 1:integer
    lv 2:integer
    exp 3:integer	
    skill_id 4:integer
}

._package {
	item 0:*item
	equipment 1:*equipment
	gem 2:*gem
	citta 3:*citta
}

.debris{
    equipment 0:*stuff_desc
    gem 1:*stuff_desc
    citta 2:*stuff_desc
    hero 3 :*stuff_desc
}

.skill {
    id 0 : integer
    level 1 : integer
    is_using 2 : boolean
    index 3 : integer
    citta_uuid 4:integer
}

.hero_attr{
    #基础属性
    attack 1 : integer
    defense 2 : integer
    max_hp 3 : integer
    critical 4 : double
    critical_defense 5 : double

    daodun_dam 6 : double
    qiangqi_dam 7 : double
    chuiche_dam 8 : double
    gongnu_dam 9 : double
    ceshi_dam 10 : double

    daodun_blk 11 : double
    qiangqi_blk 12 : double
    chuiche_blk 13 : double
    gongnu_blk 14 : double
    ceshi_blk 15 : double

    #成长
    atk_grow 16:double 
    def_grow 17:double
    hp_grow 18:double   
}


.hero_desc{
    id 0:integer
    lv 1:integer
    uuid 3:integer
    exp 4:integer
    skill_list 5 :*skill
    on 6:boolean
    grade 7 : integer
    attr 8 : hero_attr
}


.stuff_desc{
    #通用字段
    id 1 :integer
    num 2 :integer
    #部分结构拥有的字段
    uuid 3:integer
    lv 4 : integer
    exp 5 : integer
    on 6:boolean

    #equip的字段
    init_prop 7:*equipment_prop
    deify_lv 8 : integer
    inlay_list 9 :*integer
    recover_num 10 : integer

    #gem的字段
    equip_id 11 : integer 

    #心法的字段
    skill_id 12:integer

    #hero的字段
    skill_list 13 :*skill
    grade 14 : integer
    attr 15 : hero_attr
}

.char_desc{
    id 0:integer
    class_id 1:integer
    nickname 2:string
    lv 3:integer
}


.difficulty{
    level 0 : integer
    can_att 1 :boolean
    star 2 : integer
    is_first 3 : boolean
    att_time 4 : integer
}

.map_status {
    id 0 :integer
    diff 1 : *difficulty
    pre_id 2 : integer 
}

.section {
    section_id 0 : integer
    map 1 : *map_status
    can_att 2 : boolean
    total_star 3 :integer
    #章节奖励领取状态
    reward_status 4 : integer
}

.monster {
    id 0 : integer
    level 1 : integer
    drop 2 : *stuff_desc
}

.talent {
    type 0 : integer
    level 1 : integer
    is_open 2 : boolean
}

.sign_month{
    year 0 : integer
    month 1 : integer
    sign 2 : integer
}

.sign_record {
    sign_list 0 :*sign_month
    last_sign_time 1 : integer
    continual_day 2 : integer
    c_reward_num 3 : integer
}

.goods {
    id 0 :integer
    num 1 : integer
}

.fight_attr {
    #体力上限
    max_energy 1 :integer
    #血量上限
    max_hp 2 : integer
    max_sp 3 : integer
    energy 4 : integer 
    #攻击 
    attack 5 : integer
    #防御
    defense 6 : integer
    #暴击
    critical 7 : double
    #暴击防御
    critical_defense 8 : double
    move_speed 9 : double
    move_back_speed 10 : double
    move_back_duration 11 : double
    #攻击频率
    attack_rate 12 : double
    hp_recovery 13 : double
    sp_recovery 14 : double
}

.player {
	id 0 :integer
	class_id 1:integer
	nickname 2:string
	name 3:string
	vip 4:integer
    lv 5:integer
    exp 6:integer
	money 7:integer
	rmb 8:integer
    fight 9:integer
    last_add_energy_time 10 : integer

    fight_attr 11 : fight_attr
    skill_list 12 : *skill
	package 13:_package
    hero_list 14 :*hero_desc
    debris 15 :debris
    map 16 :*map_status
    talent_list 17 :*talent
    sign_record 18 : sign_record
}

.mail {
    id 0 : integer
    type 1 : integer
    src_char 2 : integer
    des_char_list 3 :*integer
    title 4 : string
    content 5 : string
    attachment 6 : *stuff_desc
    status 7 : integer
    c_time 8 : integer
}

.rank {
    char_id 0 : integer
    num 1 : integer
    name 2 : string
    likes 3 : integer
    is_liked 4 : boolean
}

.rank_info {
    list 0 :*rank
    self_rank 1 : integer
    self_num 2 : integer
}

.map_rank {
    char_id 0 : integer
    char_name 1 : string
}

.rush_rank {
    char_id 0 : integer
    char_name 1 : string
    win_num 2 : integer
    time 3 : integer
    like_num 4 :integer
    can_like 5 : boolean
}



quit 1 {}

account_login 2 {
	request {
		account_id 0 : integer
		account_name 1:string
		account_secret 2 : string
	}
	response {
		status 0:integer
		char_list 1:*char_desc
	}
}

char_create 3 {
	request {
		account_id 0:integer
		class_id 1:integer
		nickname 2:string
	}

	response {
		status 0:integer
		msg 1:string
		char_info 2:player
		char_list 3:*char_desc
	}
}

char_login 4 {
	request {
		account_id 0:integer
		char_id 1:integer
	}

	response {
		status 0:integer
		msg 1:string
		char_info 2:player
	}
}

update_game_setting 5 {
    request {
    	account_id 0:integer
    }
    response {
        status 0:integer
        msg 1:string
    } 
}

heart_beat 6 {
    request {
    }
    response {
    } 
}

#测试用接口
test_code 7 {
    request {
        parm 0 : integer
    }
    response {
        parm_int 0 : integer
        parm_str 1 : string
        parm_bool 2 : boolean
    }
}

gm_add_stuff 21 {
    request {
        id 0 : integer
        num 1 : integer
    }
    response {
        status 0 :integer
    } 
}

gm_level_up 22 {
    request {
        lv 0 : integer
    }
    response {
        status 0:integer
    } 
}


get_map_status 101 {
	request {
		
	}
	response {
        status 0 : integer
        msg 1 : string
		sections 2 :*section
	}
}
enter_map 102 {
	request {
		map_id 0 : integer
		diff 1 : integer
	}
	response {
		status 0 : integer
		msg 1 : string
        map_id 2 : integer
        diff 3 : integer
	}
}

exit_map 103
 {
	request {
        pass_status 0 : integer
		map_id 1 : integer
        diff 2 : integer
		star 3 : integer
        monsters 4 : *monster
	}
	response {
		status 0 : integer
		msg 1 : string
        map_id 2 : integer
        diff 3 : integer
        star 4 : integer
        map_reward 5: *stuff_desc
        mon_reward 6 :*stuff_desc
	}
}

get_section_reward 104
{
    request {
        section 0 : integer
        level 1 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        reward 2 :*stuff_desc
    }
}

get_map_rank 105 {
    request {
        map_id 0 : integer
        diff 1 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        rank 2 :*map_rank
        #刷新倒计时,无时为-1
        ref_countdown 3 : integer
    }   
}

#物品出售传id和num，装备宝石只要传uuid就可以了
sell_item 201 {
    request {
    	id 1:integer
    	num 3:integer
    }
    response {
        status 0:integer
        msg 1:string
        get_stuff_list 3:*stuff_desc
    } 
}

use_item 202 {
    request {
    	id 1:integer
    	num 2:integer
    }
    response {
        status 0:integer
        msg 1:string
        get_stuff_list 3:*stuff_desc
    } 
}

#使用药品
use_medicine 203 {
    request {
    }
    response {
        status 0:integer
        msg 1:string
        id 2 : integer
    }
}

#战斗中复活
relive 204 {
    request {
    }
    response {
        status 0:integer
        msg 1:string
        cost 2 : integer
    }
}

add_stuff 300 {
    request {
        stuff_list 0:*stuff_desc
    }
    response {
        status 0:integer
        msg 1:string
        package 2: _package
    } 
}

lv_up_citta 301 {
    request {
        uuid 0:integer
        citta_list 2:*integer
    }
    response {
        status 0:integer
        msg 1:string
        citta 2:citta
    } 
}

compound_citta 302 {
    request {
        make_id 1:integer
    }
    response {
        status 0:integer
        msg 1:string
        citta 2:citta
    } 
}

equip_citta 303 {
    request {
        skill_id 0:integer
        citta_uuid 1:integer
    }
    response {
        status 0:integer
        msg 1:string
    } 
}

get_skill_list 401 {
    request {
        type 0 : integer
        hero_id 1 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        skill 2 : *skill 
    }
}

get_using_skill_list 402 {
     request {    
    }
    response {
        status 0 : integer
        msg 1 : string
        skill 2 : *skill 
    }
}

skill_unlock 403 {
    request {
        id 0 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
    }
}

skill_level_up 404 {
    request {
        up_type 0 : integer
        hero_id 1 : integer
        skill_id 2 : integer   
    }
    response {
        status 0 : integer
        msg 1 : string
    }
}

skill_put_on 405 {
    request {
        id 0 : integer
        index 1 : integer
    }
    response {
        status 0 : integer
        msg 1 :string
    }
}

hero_add_exp 501{
    request {
        uuid 0 : integer
        stuff_list 1:*stuff_desc
    }
    response {
        status 0 : integer
        msg 1 :string
        uuid 2 : integer
        add_exp 3 : integer
        stuff_list 4:*stuff_desc
    }
}

hero_refined 502{
    request {
        uuid 0 : integer
        from_uuid 1:integer
    }
    response {
        status 0 : integer
        msg 1 :string
        uuid 2 : integer
        from_uuid 3:integer
        atk_grow 4:double
        def_grow 5:double
        hp_grow 6:double
    }
}

hero_refined_back 503{
    request {
        uuid 0 : integer
        from_uuid 1:integer
    }
    response {
        status 0 : integer
        msg 1 :string
        success 2:boolean
        idx 3:integer
        aptitude 4:string
        apt_value 5:integer
    }
}

hero_up_grade 504{
    request {
        uuid 0 : integer
    }
    response {
        status 0 : integer
        msg 1 :string
        uuid 2 : integer
        new_attr 3 : hero_attr
        cost_list 4 :*stuff_desc
    }
}

hero_break_up 505{
    request {
        uuid 0 : integer
    }
    response {
        status 0 : integer
        msg 1 :string
    }
}

hero_on_off 506{
    request {
        uuid_list 0 : *integer
        on 1 :boolean        
    }
    response {
        status 0 : integer
        msg 1 :string
    }
}

hero_summon 507 {
    request {
        hero_id 0 : integer        
    }
    response {
        status 0 : integer
        msg 1 :string
        new_hero 2 : hero_desc
    } 
}


talent_level_up 601 {
    request {
        type 0 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
    }
}

equip_put_on 701 {
    request {
        uuid 0 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        uuid 2 : integer
    }
}

equip_put_off 702 {
    request {
        uuid 0 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        uuid 2 :integer
    }
}

#装备洗练
equip_infuse 703 {
    request {
        #消耗材料
        src_uuid 0 : integer
        #被洗练的装备
        des_uuid 1 : integer
        #要洗练的属性序号
        prop_index 2 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        new_equip 2 :equipment
        #恢复需要金币
        recover_cost 3 : integer
    }
}

#装备洗练恢复
equip_infuse_recover 704 {
     request {
        uuid 0 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        new_equip 2 :equipment
        #恢复消耗掉的材料
        src_equip 3 :equipment
    }
}

#装备强化
equip_level_up 705 {
    request {
        uuid 0 : integer
        #连升十级
        is_ten 1 : boolean
    }
    response {
        status 0 : integer
        msg 1 : string
        new_equip 2 : equipment
    }
}

#装备神化，增加基础属性并打孔
equip_deify 706 {
    request {
        uuid 0 : integer
    }
    response {
        status 0 :integer
        msg 1 : string
        new_equip 2 : equipment
    }
}

#装备镶嵌
equip_inlay 707 {
    request {
        equip_uuid 0 : integer
        slot_index 1 : integer
        gem_uuid 2 : integer
    }
    response {
        status 0 :integer
        msg 1 : string
    }
}

#装备镶嵌移除
equip_inlay_remove 708 {
    request {
        equip_uuid 0 : integer
        slot_index 1 : integer
    }
    response {
        status 0 :integer
        msg 1 : string
    }
}

#装备合成
equip_synthesis 709 {
    request {
        #对于不同人物，一种碎片可以合成不同的装备
        recipe_id 0 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        new_equip 2 : equipment
    }
}

#装备分解
equip_decompose 710 {
    request {
        uuid 0 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        #得到的产物
        product 2 :*stuff_desc
    }
}



get_mail_list 801 {
    request {
    
    }
    response {
        status 0 :integer
        msg 1 : string
        mail_list 2 : *mail
    }
}

read_mail 802 {
    request {
        mail_id 0 : integer
    }
    response {
        status 0 :integer
        msg 1 : string
    }
}

get_mail_attachment 803 {
    request {
        mail_id 0 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        attachment 2 : *stuff_desc
    }
}

delete_mail 804 {
    request {
        mail_id 0 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
    }
}

get_all_mail_attachment 805 {
    request {
        
    }
    response {
        status 0 : integer
        msg 1 : string
        attachment 2 : *stuff_desc
    }
}

send_mail 806 {
    request {
        mail_data 0 : mail
    }
    response {
        status 0 : integer
        msg 1 : string
    }
}

sign_up 901 {
    request {

    }
    response {
        status 0 : integer
        msg 1 : string
        daily_reward 2 :*stuff_desc
        continual_reward 3 :*stuff_desc
    }   
}

get_sign_ranking 902 {
    request {

    }
    response {
        status 0 : integer
        msg 1 : string
        rank_info 2 :rank_info
    }
}

sign_ranking_likes 903 {
    request {
        char_id 0 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        reward 2 :*stuff_desc
    }
}

recharge_order 1001 {
    request {
        pay_point 0 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        order 2:string 
    }   
}

get_goods_list 1101 {
    request {
        type 0 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        goods_list 2 :*goods
        ref_num 3 : integer
        ref_time 4 : integer
    }     
}

buy_goods 1102 {
    request {
        type 0 : integer
        index 1 : integer
        num 2 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        goods 2 : stuff_desc
    }    
}

refresh_treasure 1103 {
    request {

    }
    response {
        status 0 : integer
        msg 1 : string
        goods_list 2 :*goods
    }   
}

gem_synthesis 1201 {
    request {
        recipe_id 0 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        new_gem 2 : gem
    }
}

gem_level_up 1202 {
    request {
        src_list 0 :*integer
        des_uuid 1 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        new_gem 2 : gem
    }
}

#获取急行战信息
get_rush_info 1301 {
    request {
    }
    response {
        status 0 : integer
        msg 1 : string
        #剩余挑战次数
        remain_num 2 :integer
        #购买次数消耗
        buy_cost 3:integer
        #难度等级段
        level 4 :integer
        #连胜次数
        vic_num 5 : integer
    }
}

#急行战开始匹配
rush_match_begin 1302 {
    request {
    }
    response {
        status 0 : integer
        msg 1 : string
    }
}

#急行战取消匹配
rush_match_cancel 1303 {
    request {
    }
    response {
        status 0 : integer
        msg 1 : string
    }
}

#急行战载入完毕
rush_loaded 1304 {
    request {
    }
    response {
        status 0 : integer
        msg 1 : string
    }
}

#急行战位置消息
rush_position 1305 {
    request {
        position 0 : double
    }
    response {
        status 0 : integer
        msg 1 : string
    }
}

#急行战击杀怪物通知
rush_kill_mon 1306 {
    request {
        #怪物id
        mon_id  0 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
    }
}

#急行战boss血量通知
rush_boss_hp 1307 {
    request {
        #百分比
        boss_hp  0 : double
    }
    response {
        status 0 : integer
        msg 1 : string
    }
}

#急行战通关请求
rush_pass 1308 {
    request {
        #0 : 中途退出 1：通关
        status 0 : integer
        #通关耗时
        time 1 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
    }
}

#急行战获取排行榜
get_rush_rank 1309 {
    request {
        level  0 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        rank_list 2 :*rush_rank
    }
}

#急行战排行榜点赞
rush_rank_like 1310 {
    request {
        char_id 0 : integer
        level 1 : integer
    }
    response {
        status 0 : integer
        msg 1 : string
        reward 2 :*stuff_desc
    }
}


















