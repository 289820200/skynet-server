--------------------------------------
-- @Author:      Mark
-- @DateTime:    2015-5-11 
-- @Description:  排序二叉树
--------------------------------------
local print_r = require "common.print_r"
Bs_tree={
    
}


--要传入一个创建好的table
function Bs_tree.insert( t,e )
    if not t then
        return false
    end

    if not t.data then
        t.key = e.key
        t.data = e.data
        return true
    end

    --后插入的视为大
    if e.key < t.key then
        if not t.l_child then
            t.l_child = e
            t.l_child.parent = t
            return true
        else
            return Bs_tree.insert(t.l_child)
        end
    else
        if not t.r_child then
            t.r_child = e
            t.r_child.parent = t
            return true
        else
            return Bs_tree.insert(t.r_child)
        end
    end
end

--这个遍历不要修改
function Bs_tree.traverse( t,func )
    if not t then
        return
    end

    if func then
        func(t)
    end

    Bs_tree.traverse(t.l_child)
    Bs_tree.traverse(t.r_child)
end


function Bs_tree.find( t,key )
    if not t then
        return nil
    end
    if t.key == key then
        return t
    end

    if t.key < key then
        return Bs_tree.find(t.l_child)
    else
        return Bs_tree.find(t.r_child)
    end
end

--查找data，视为普通二叉树
function Bs_tree.find_data( t,name,value )
    if (not t) or (not t.data) then
        return nil
    end

    if t.data[name] == value then
        return t
    end

    local e = Bs_tree.find_data(t.l_child)
    if e then
        return e
    end

    local e = Bs_tree.find_data(t.r_child)
    if e then
        return e
    end

    return nil
end

--最好用在键值唯一的树上
function Bs_tree.delete( t,key )
    local e = Bs_tree.find(t,key)
    if not e then
        return false
    end

    return Bs_tree.e_delete(t,e)
end


--查找值在一定范围内，并且不等于e的节点
function Bs_tree.r_find( t,min,max,e )
    if not t then
        return nil
    end
    --print("r_find",t.key,min,max,t==e)
    if t.key >= min and t.key <= max and t~= e then
        return t
    end

    if t.key < min then
        return Bs_tree.r_find(t.l_child)
    else
        return Bs_tree.r_find(t.r_child)
    end
end


--获取节点指针之后使用,有点烂，回头再改
function Bs_tree.e_delete( t,e )
    if (not t) or (not e) then
        return false
    end

    if e.l_child then
        if e.r_child then
            --e的左子树作为e的双亲的左/右子树（视e为左/右子树而定），
            --e的右子树作为e的左子树最右下节点的右子树
            if e.parent then
                if e.key < e.parent.key then
                    e.parent.l_child = e.l_child
                    e.l_child.parent = e.parent
                else
                    e.parent.r_child = e.l_child
                    e.l_child.parent = e.parent
                end
            else
                t = e.l_child
            end

            local tmp = e.l_child
            while(tmp.r_child) do
                tmp = tmp.r_child
            end

            tmp.r_child = e.r_child
            e.r_child.parent = tmp
        else
            --只有左子树
            if e.parent then
                if e.key < e.parent.key then
                    e.parent.l_child = e.l_child
                    e.l_child.parent = e.parent
                else
                    e.parent.r_child = e.l_child
                    e.l_child.parent = e.parent
                end
            else
                t = e.l_child
                e.l_child.parent = nil
            end
        end
    elseif e.r_child then
        --只有右子树
        if e.parent then
            if e.key < e.parent.key then
                e.parent.l_child = e.r_child
                e.r_child.parent = e.parent
            else
                e.parent.r_child = e.r_child
                e.r_child.parent = e.parent
            end
        else
            t = e.r_child
            e.r_child.parent = nil
        end
    else
        --无子树直接删除
        if e.parent then
            if e.key < e.parent.key then
                e.parent.l_child = nil
            else
                e.parent.r_child = nil
            end
        else
            t = {}
        end     
    end
    print("delete e,char_id:",e.data.char_id)
    e.parent = nil
    e.l_child = nil
    e.r_child = nil

    return true,t
end



