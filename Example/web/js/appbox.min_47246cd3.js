var userId = "";
window.onload = function() {
    hideLoading();
}

/**
 * sdk登录
 */
function login(cb){
    window.bridge.login( function (result) {
        var json = JSON.parse(result);
        if (json.code === 1) {
            console.log("登录成功"+json.userId);
            userId = json.userId;
            console.log("userId---"+userId);
            if(cb)cb(cb);
        }
    });
}

/**
 * 设置登出回调
 */
function setLogoutCb(cb){
    this.logoutCb = cb;
}

/**
 * 登出
 */
function logoutFromNative() {
    console.log("收到登出");
    login(logoutCb);
}

/**
 * 登出sdk
 */
function logout() {
    window.bridge.logout( function (code) {
        if (code === 1) {
            console.log("登出成功");
        }
    })
}

/**
 * 关闭游戏
 */
function btn_close() {
	window.bridge.closeGame();
}

function hideLoading(){
    window.bridge.hideLoading();
}
