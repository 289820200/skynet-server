
.package {
	type 0 : integer
	session 1 : integer
	msg 2 : string
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



announcement 20101 {
	request {
		message 0 : string
	}
	response {
	
	}
}

mail_notify 20201 {
    request {
        mail_num 0 : integer
        mail_data 1 : mail
    }
    response {

    }
}


recharge_notify 20301 {
    request {
        pay_point 0 : integer 
        rmb 1:integer
        money 2:integer
    }
    response {
    }
}

restore_energy_notify 20401 {
    request {
        add_energy 0 : integer
    }
    response {
    }
}

add_stuff_notify 20402 {
    request {
       stuff_list 0 :*stuff_desc
    }
    response {
    }
}


fight_attr_change_notify 20404 {
    request {
       lv 0 : integer
       fight_attr 1 : fight_attr
    }
    response {
    }
}


gm_command 20501 {
    request {
        status 0 : integer
        char_data 1 : player
    }
    response {
    }
}

rush_match_result 20601 {
    request {
        status 0 : integer
        msg 1 : string
        #自己的连败次数
        lose_num 2 : integer
        char_name 3 : string
        fight 4 : integer
        #给heroid即可
        hero_list 5 :*integer
    }
    response {
    }
}

#急行战载入完毕
rush_loaded 20602 {
    request {
    }
    response {

    }
}

#急行战位置消息
rush_position 20603 {
    request {
        position 0 : double
    }
    response {
    }
}

#急行战击杀怪物通知
rush_kill_mon 20604 {
    request {
        #怪物id
        mon_id  0 : integer
    }
    response {

    }
}

#急行战boss血量通知
rush_boss_hp 20605 {
    request {
        #百分比
        boss_hp  0 : double
    }
    response {

    }
}

#急行战结果
rush_result 20606 {
    request {
        #1：胜利 2：对方胜利 3：双方超时
        result 0 : integer
        time 1 : integer
        reward 2 :*stuff_desc
    }
    response {

    }
}
