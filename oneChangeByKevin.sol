pragma solidity ^0.4.18;

/* 地址压缩工具
 * 本合约可以作为全网的基础设施，维护一份20byte地址数据到4byte无符号整数的双向映射(能存储大概43亿个地址)
 * 如果某个合约需要存储大量重复地址信息(例如一元夺宝合约每一个商品都要存储所有购买用户的地址列表，不同商品的购买用户列表很大程度上是重复的)
 * 可以调用本合约将地址压缩为4byte后存储
 * 本合约只在用户第一次注册时消耗gas存储用户地址信息，之后用户address到uid的双向查询都不需要成本
 * 如果后续需要限制恶意注册消耗合约的用户地址空间(32bit支持大约43亿地址),可以考虑注册时收取微量费用
 */
contract AddressCompress {
    
    mapping (address => uint32) public uidOf;
    mapping (address => address) public addrOf;
    
    uint32 public topUid;
    
    function regist(address addr) public returns (uint32 uid){
        if(uidOf[addr] != 0) return;
        uid = ++topUid;
        uidOf[addr] = uid;
        addrOf[uid] = addr;
    }
}