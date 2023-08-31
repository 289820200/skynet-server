--------------------------------------
-- @Author:      Mark
-- @DateTime:    2016-01-05 
-- @Description:  邮件处理
--------------------------------------

local skynet = require "skynet"
local sharedata = require "skynet.sharedata"

local log = require "log"
local dbpacker = require "db.packer"
local handler = require "request_handler.handler"
local print_r = require "common.print_r"

require "polo.Mail"

local REQUEST = {}
handler = handler.new (REQUEST)

local user
local database
local gdd
local mail_cache
local max_mail_id

handler:init (function (u)
    user = u
    database = ".database" 
    gdd  = sharedata.query "settings_data"
    mail_cache = {}
    max_mail_id = 0
end)

local function build_mail_list(  )
    local char = user.character
    local mail_list = char.mail_list

    --增量获取新邮件
    local max_char_mail = max_mail_id or 0
    local new_mail_list = skynet.call(database,"lua","mail","list",char.id,max_char_mail)
    for k,v in pairs(new_mail_list) do
        local find = false
        for m,n in pairs(mail_list) do
            if n.id == v.id then
                v.status = n.status
                find = true
                break
            end
        end
        if not find then
            v.status = 0
            table.insert( mail_list,{id=v.id,status=0} )
        end

        local tmp_mail = Mail:new(v)
        table.insert( mail_cache,tmp_mail )

        if not max_mail_id or v.id > max_mail_id then
            max_mail_id = v.id
        end
    end
end

--更新角色数据里的邮件列表
local function update_mail_list( mail_id,status )
    local char = user.character
    local mail_list = char.mail_list

    local find = false
    for i,v in ipairs(mail_list) do
        if v.id == mail_id then
            find = true
            --用-1表示删除邮件
            if status == -1 then
                table.remove(mail_list,i)
                break
            else
                v.status = status
                break
            end
        end
    end

    if not find and status ~= -1 then
        table.insert( char.mail_list,{id=mail_id,status=2} )
    end
end


--获取邮件列表
function REQUEST.get_mail_list( args )
    local char = user.character

    --构建邮件列表
    build_mail_list()

    --读取邮件列表
    local ret_mail_list = {}
    for i,v in ipairs(mail_cache) do
        local tmp = {}
        tmp.id = v.id
        tmp.status = v.status
        tmp.src_char = v.src_char  
        tmp.title = v.title
        tmp.content = v.content
        tmp.attachment = v.attachment
        tmp.c_time = v.c_time
        table.insert(ret_mail_list,tmp)
    end
    --排序一下
    table.sort( ret_mail_list,function ( lhs,rhs )
        if lhs.status == rhs.status then
            return lhs.id < rhs.id
        else
            return lhs.status < rhs.status
        end
    end )

    char:mark_updated()
    return {status=1,msg="",mail_list=ret_mail_list}
end

local function get_target_mail( mail_id )
    local char = user.character
    local mail_list = char.mail_list

    for i,v in ipairs(mail_cache) do
        if v.id == mail_id then
            --target_mail,index
            return v,i
        end
    end
    
    return nil
end

--读邮件
function REQUEST.read_mail( args )
    local mail_id = args.mail_id
    local char = user.character
    
    --本地邮件列表里有没有该邮件
    local target_mail = get_target_mail(mail_id)
    if not target_mail then
        return {status=0,msg="no this mail"}
    end

    local ok,mail_status = target_mail:read()

    --更新邮件列表
    if ok then
        update_mail_list(mail_id,mail_status)
    else
        return {status=0,msg="read mail err"}
    end

    char:mark_updated()
    return {status=1,msg=""}

end

function REQUEST.get_mail_attachment( args )
    local mail_id = args.mail_id
    local char = user.character

    --本地邮件列表里有没有该邮件
    local target_mail = get_target_mail(mail_id)
    if not target_mail then
        return {status=0,"no this mail"}
    end

    --设置领取状态    
    local attachment,msg = target_mail:get_attachment()
    if not attachment then
        return {status=0,msg=msg}
    end

    --更新角色已读邮件列表
    update_mail_list(mail_id,2)

    --发奖励
    attachment = char:give_reward(attachment,"mail attachment")

    char:mark_updated()
    return {status=1,msg="",attachment=attachment}
end

function REQUEST.delete_mail( args )
    local mail_id = args.mail_id
    local char = user.character

    --本地邮件列表里有没有该邮件
    local target_mail,index = get_target_mail(mail_id)
    if not target_mail then
        return {status=0,msg="no this mail"}
    end

    local ok,msg = target_mail:delete(char.id)
    if not ok then
        return {status=0,msg=msg}
    end
    
    --释放掉缓存  
    table.remove(mail_cache,index)

    --在已读邮件列表中删除
    update_mail_list(mail_id,-1)

    char:mark_updated()
    return {status=1,msg=""}
end

function REQUEST.get_all_mail_attachment( args )
    local mail_id = args.mail_id
    local char = user.character
    local mail_list = char.mail_list

    local total_attachment = {}
    for k,v in pairs(mail_cache) do
        local attachment = v:get_attachment()
        if attachment then
            --不同邮件的附件不合并在一起
            for m,n in pairs(attachment) do
                table.insert(total_attachment,n)
            end
            update_mail_list(v.id,2)
        end
    end

     --发奖励
    total_attachment = char:give_reward(total_attachment,"mail attachment")

    char:mark_updated()
    return {status=1,msg="",attachment=total_attachment}
end

--发送邮件,暂时不开放这功能，测试用
function REQUEST.send_mail( args )
    local mail_data = args.mail_data

    local result = skynet.call("mail_center","lua","send_mail",mail_data)
    if not result then
        return {status=0,msg="send mail err"}
    end
    
    return {status=1,msg=""}
end

--接收邮件
function REQUEST.accept_mail( mail_data )
    --先初始化邮件列表
    build_mail_list()

     --本地邮件列表里有没有该邮件
    local target_mail,index = get_target_mail(mail_data.id)
    if not target_mail then
        mail_data.status = 0
        table.insert( mail_cache,mail_data)
    end

    return true
end

return handler


