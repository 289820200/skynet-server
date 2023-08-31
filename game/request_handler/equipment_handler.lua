local skynet = require "skynet"
local sharedata = require "skynet.sharedata"

local log = require "log"
local dbpacker = require "db.packer"
local handler = require "request_handler.handler"
local print_r = require "common.print_r"

require "polo.Equipment"
require "polo.StuffFactory"
require "common.predefine"

local REQUEST = {}
handler = handler.new (REQUEST)

local user
local database
local gdd

handler:init (function (u)
	user = u
	database = ".database" 
	gdd  = sharedata.query "settings_data"
end)


function REQUEST.equip_put_on(req)
    local char = user.character
	local uuid = req.uuid 
    if not uuid then 
        return char:get_error_ret("参数有误")
    end

    local ok,msg =  char:equip(uuid)
    if not ok then
        return char:get_error_ret(msg)
    end

    return char:get_succ_ret({uuid=uuid})
end

function REQUEST.equip_put_off(req)

    local uuid = req.uuid 
    if not uuid then 
        return char:get_error_ret("参数有误")
    end
    local char = user.character

	local ok,msg =  char:equip_off(uuid)
    if not ok then
        return char:get_error_ret(msg)
    end

    return char:get_succ_ret({uuid=uuid})
end

--装备洗练，相当于消耗一个装备给另一个装备注入属性
--消耗材料随机一个属性取代目标装备的属性。客户端计算随到哪个属性
function REQUEST.equip_infuse( req )
    local char = user.character
    local src_uuid = req.src_uuid
    local des_uuid = req.des_uuid
    local prop_index = req.prop_index

    --src是作为材料消耗掉那个装备
    local src_equip = char:get_stuff_by_uuid("equipment",src_uuid)
    if not src_equip then
        return char:get_error_ret("cant find src equip")
    end

    if src_equip.on == true then
        return char:get_error_ret("src_equip is on")
    end

    local des_equip = char:get_stuff_by_uuid("equipment",des_uuid)
    if not des_equip then
        return char:get_error_ret("cant find des equip")
    end

    --新增属性
    local src_prop
    if src_equip.init_prop and next(src_equip.init_prop) then
        local src_prop_index = math.random(1,#src_equip.init_prop)
        src_prop = src_equip.init_prop[src_prop_index]
    else
        return char:get_error_ret("src equip prop nil")
    end

    local src_data = Equipment.get_data(src_equip.id)
    if not src_data then
        char:get_error_ret("src equip conf err")
    end
    local des_data = Equipment.get_data(des_equip.id)
    if not des_data then
        char:get_error_ret("des equip conf err")
    end
    if src_data.eq_type ~= des_data.eq_type then
        return char:get_error_ret("equip type not same")
    end

    if not des_equip.init_prop[prop_index] then
        --新增属性不能使属性列表离散
        local prop_num = #des_equip.init_prop
        if prop_num < des_data.max_prop_count then
            prop_index = #des_equip.init_prop + 1
        else
            return char:get_error_ret("prop num max")
        end
    end

    --装备恢复价格
    local rc_num = (src_equip.recover_num or 0) + 1
    local rc_cost_list = src_data.recover_cost_list
    if not rc_cost_list then
        return char:get_error_ret("recover cost nil")
    end
    rec_cost = rc_cost_list[rc_num] or rc_cost_list[#rc_cost_list]
    if not rec_cost then
        return char:get_error_ret("recover cost err")
    end
        
    --把洗练状态保存起来，可以花钱恢复
    --恢复请求只有在没关闭洗练界面时出现。所以只记录最后洗练装备的信息
    local equip_infuse_rec = {}
    equip_infuse_rec.src_equip = src_equip
    equip_infuse_rec.des_uuid = des_uuid
    equip_infuse_rec.prop_index = prop_index
    equip_infuse_rec.old_prop = des_equip.init_prop[prop_index] or nil
    char.equip_infuse_rec = equip_infuse_rec

    --返回宝石
    if src_equip.inlay_list then
        for k,v in pairs(src_equip.inlay_list) do
            if v~= -1 then
                local gem = char:get_stuff_by_uuid("gem",v)
                if gem then
                    gem.equip_id = nil
                end
            end
        end
    end

    if (not char:delete_stuff("equipment",src_uuid)) then
        return char:get_error_ret("del src equip err")
    end

    des_equip.init_prop[prop_index] = src_prop
    
    char:mark_updated()
    return char:get_succ_ret({new_equip = des_equip,recover_cost = rec_cost})
end

--恢复洗练的属性
local function recover_equip( des_equip )
    local char = user.character
    local infuse_rec = char.equip_infuse_rec

    des_equip.init_prop[infuse_rec.prop_index] = infuse_rec.old_prop
end

function REQUEST.equip_infuse_recover( req )
    local char = user.character
    local uuid = req.uuid
    --应该是不会出现这种异常的
    if (not char.equip_infuse_rec) or uuid ~= char.equip_infuse_rec.des_uuid then
        return char:get_error_ret("cant recover")
    end

    local des_equip = char:get_stuff_by_uuid("equipment",uuid)
    if not des_equip then
        return char:get_error_ret("cant find des equip")
    end

    local infuse_rec = char.equip_infuse_rec
    local src_equip = infuse_rec.src_equip
    local rc_num = (src_equip.recover_num or 0) + 1
    local cost

    local src_data = Equipment.get_data(src_equip.id)
    if not src_data then
        char:get_error_ret("src equip conf err")
    end

    local rc_cost_list = src_data.recover_cost_list
    if not rc_cost_list then
        return char:get_error_ret("recover cost nil")
    end
    cost = rc_cost_list[rc_num] or rc_cost_list[#rc_cost_list]
    if not cost then
        return char:get_error_ret("recover cost err")
    end

    --扣钱
    if not char:is_stuff_enough(RMB_ID,cost) then
        return char:get_error_ret("rmb not enough")
    end
    char:add_stuff(RMB_ID,-cost,"equip infuse recover")

    --恢复属性
    recover_equip(des_equip)

    --把消耗掉的装备塞回去
    src_equip.recover_num = rc_num
    src_equip.on = false
    local type_stuff = char.package.equipment
    table.insert( type_stuff,src_equip )

    --设置宝石
    if src_equip.inlay_list then
        for k,v in pairs(src_equip.inlay_list) do
            if v~= -1 then
                local gem = char:get_stuff_by_uuid("gem",v)
                if gem then
                    gem.equip_id = src_equip.uuid
                end
            end
        end
    end

    char.equip_infuse_rec = nil

    char:mark_updated()
    return char:get_succ_ret({new_equip = des_equip,src_equip=src_equip})
end


--装备强化
function REQUEST.equip_level_up( req )
    local char = user.character
    local uuid = req.uuid
    local is_ten = req.is_ten

    if not uuid then
        return char:get_error_ret("uuid nil")
    end

    local target_equip = char:get_stuff_by_uuid("equipment",uuid)
    if not target_equip then
        return char:get_error_ret("cant find equip")
    end

    --装备配置
    local data = Equipment.get_data(target_equip.id)
    if not data then
        char:get_error_ret("target equip conf err")
    end

    --强化配置
    local conf_set = gdd.equip_level_up
    local conf = conf_set[target_equip.id]
    if not conf then
        return char:get_error_ret("conf err")
    end

    --检测是否可以强化
    local up_num
    local equip_lv = target_equip.lv or 0
    if is_ten then
        local max_level = math.min(char.lv * 3,#conf)
        if equip_lv >= max_level then
            return char:get_error_ret("equip lv max")
        end

        local lv_by_cost = Equipment.get_max_level_by_cost(target_equip.id,equip_lv,char.money)
        max_level = math.min(max_level,lv_by_cost)
        if equip_lv >= max_level then
            return char:get_error_ret("money not enough")
        end

        up_num = max_level - equip_lv
        up_num = math.min(up_num,10)
    else
        up_num = 1
    end
    
    --检测消耗是否足够
    local total_cost,msg = Equipment.get_level_up_cost(target_equip.id,equip_lv,equip_lv+up_num)
    if total_cost < 0 then
        return char:get_error_ret(msg)
    end

    if not char:is_stuff_enough(MONEY_ID,total_cost) then
        return char:get_error_ret("money not enough")
    end 

    --扣除消耗
    char:add_stuff(MONEY_ID,-total_cost,"equip lv up")

    local new_lv = equip_lv + up_num
    --改变强化等级
    target_equip.lv = new_lv

    --发送广播
    if new_lv == 120 or new_lv == 150 or new_lv == 180 then
        local msg = string.format("哇，真厉害，玩家%s已经将%s强化到+%d级！",char.nickname,data.name,new_lv)
        user:publish_world_broadcast(msg)
    end

    char:mark_updated()
    return char:get_succ_ret({new_equip = target_equip})
end


function REQUEST.equip_deify( req )
    local char = user.character
    local uuid = req.uuid

    local target_equip = char:get_stuff_by_uuid("equipment",uuid)
    if not target_equip then
        return char:get_error_ret("cant find equip")
    end

    --装备配置
    local data = Equipment.get_data(target_equip.id)
    if not data then
        char:get_error_ret("target equip conf err")
    end

    local deify_lv = (target_equip.deify_lv or 0) + 1
    local equip_lv = target_equip.lv

    if deify_lv > 3 then
        return char:get_error_ret("deity lv max")
    end

    local need_lv = data.deify_lv_list[deify_lv]

    --检查强化等级
    if equip_lv < need_lv then
        return char:get_error_ret("equip lv too low")
    end

    local cost = data.deify_cost_list[deify_lv]
    
    --消耗
    if not char:is_stuff_enough(RMB_ID,cost) then
        return char:get_error_ret("rmb not enough")
    end

    char:add_stuff(RMB_ID,-cost)

    target_equip.deify_lv = deify_lv

    --开孔
    local inlay_list = target_equip.inlay_list or {}
    table.insert( inlay_list,-1)
    target_equip.inlay_list = inlay_list

    char:mark_updated()
    return char:get_succ_ret({new_equip=target_equip})
end

function REQUEST.equip_inlay( req )
    local char = user.character
    local equip_uuid = req.equip_uuid
    local gem_uuid = req.gem_uuid
    local slot_index = req.slot_index

    local equip = char:get_stuff_by_uuid("equipment",equip_uuid)
    if not equip then
        return char:get_error_ret("cant find equip")
    end

    local gem = char:get_stuff_by_uuid("gem",gem_uuid)
    if not gem then
        return char:get_error_ret("cant find gem")
    end
    local gem_data = gem:get_data()
    if not gem_data then
        return false,"gem data err"
    end

    if (not equip.inlay_list) or (not equip.inlay_list[slot_index]) then
        return char:get_error_ret("dont have this slot")
    end

    --同类宝石只能镶嵌一个
    for k,v in pairs(equip.inlay_list) do
        local tmp_gem = char:get_stuff_by_uuid("gem",v)
        if tmp_gem then
            local tmp_gem_data = tmp_gem:get_data()
            if tmp_gem_data and tmp_gem_data.id == gem_data.id then
                return char:get_error_ret("have same type gem")
            end
        end
    end

    local ok,msg = equip:inlay(slot_index,gem)
    if not ok then
        return char:get_error_ret(msg)
    end
    gem.equip_id = equip.uuid

    char:mark_updated()
    return char:get_succ_ret()
end

--移除宝石
function REQUEST.equip_inlay_remove( req )
    local char = user.character
    local equip_uuid = req.equip_uuid
    local slot_index = req.slot_index

    local equip = char:get_stuff_by_uuid("equipment",equip_uuid)
    if not equip then
        return char:get_error_ret("cant find equip")
    end

    if (not equip.inlay_list) or (not equip.inlay_list[slot_index]) then
        return char:get_error_ret("dont have this slot")
    end

    if equip.inlay_list[slot_index] == -1 then
        return char:get_error_ret("slot empty")
    end

    local gem = char:get_stuff_by_uuid("gem",equip.inlay_list[slot_index])
    if not gem then
        return char:get_error_ret("cant find gem")
    end

    local cost = INLAY_REMOVE_COST

     --消耗
    if not char:is_stuff_enough(RMB_ID,cost) then
        return char:get_error_ret("rmb not enough")
    end

    char:add_stuff(RMB_ID,-cost)

    local ok,msg = equip:inlay_remove(slot_index)
    if not ok then
        return char:get_error_ret(msg)
    end
    gem.equip_id = nil

    return char:get_succ_ret()
end

--装备合成，用装备碎片合成装备
--故意不用decompose的反义词compose，因为这里的合成和分解不是对等的
function REQUEST.equip_synthesis( req )
    local char = user.character
    local recipe_id = req.recipe_id

    local conf = gdd.recipe[recipe_id]
    if not conf then
        return char:get_error_ret("recipe conf err")
    end

    if not conf.type ==  1 then
        return char:get_error_ret("recipe type err")
    end

    --对于不同人物，一种碎片可以合成不同的装备
    local equip_id = conf.product_list[char.class_id] or conf.product_list[1]
    if not equip_id then
        return char:get_error_ret("equip id err")
    end

    local equip_conf = gdd.equipment[equip_id]
    if not equip_conf then
        return char:get_error_ret("equip conf err")
    end

    for k,v in pairs(conf.material_list) do
        if not char:is_stuff_enough(v.id,v.num) then
            return char:get_error_ret("material num not enough")
        end
    end

    for k,v in pairs(conf.material_list) do
        char:add_stuff(v.id,-v.num,"equip synthesis")
    end

    --添加装备
    local new_equip = char:add_equipment(equip_id,1)
    
    --发送广播 白绿蓝紫橙 12345
    if equip_conf.quality >=4 then
        local msg = string.format("恭喜%s，成功合成%s装备！",char.nickname,equip_conf.name)
        user:publish_world_broadcast(msg)
    end

    char:mark_updated()
    --add_equip返回table
    return char:get_succ_ret({new_equip = new_equip[1]})
end

--装备分解，把装备分解成兑换装备的代币
function REQUEST.equip_decompose( req )
    local char = user.character
    local uuid = req.uuid

    local equip = char:get_stuff_by_uuid("equipment",uuid)
    if not equip then
        return char:get_error_ret("cant find equip")
    end

    if not char:delete_stuff("equipment",uuid) then
        return char:get_error_ret("equip delete fail")
    end

    --拆分产物
    local product,msg = equip:decompose()
    if not product then
        return char:get_error_ret(msg)
    end

    --强化强化耗费归还80%
    local total_cost,msg = Equipment.get_level_up_cost(equip.id,1,equip. lv)
    if total_cost < 0 then
        return char:get_error_ret(msg)
    end
    if total_cost > 0 then
        local return_num = math.floor(total_cost * 0.8)
        table.insert(product,{id=MONEY_ID,num=return_num})
    end

    product = char:give_reward(product,"equip decompose")
    
    --返还宝石
    if equip.inlay_list then
        for k,v in pairs(equip.inlay_list) do
            if v ~= -1 then
                local gem = char:get_stuff_by_uuid("gem",v)
                if gem then
                    gem.equip_id = nil
                end
            end
        end
    end

    char:mark_updated()
    return char:get_succ_ret({product=product})
end

return handler

