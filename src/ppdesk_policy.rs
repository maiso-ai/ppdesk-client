use hbb_common::config::{self, keys, Config};

pub const ID_SERVER: &str = "192.168.2.32:21116";
pub const RELAY_SERVER: &str = "192.168.2.32:21117";
pub const API_SERVER: &str = "http://192.168.2.32:21114";
pub const SERVER_KEY: &str = "mo76eenRkunA21Grx9PWrzlaabKiePFbHD70d1+A394=";

pub fn apply() {
    {
        let mut settings = config::OVERWRITE_SETTINGS.write().unwrap();
        settings.remove(keys::OPTION_PROXY_URL);
        settings.remove(keys::OPTION_PROXY_USERNAME);
        settings.remove(keys::OPTION_PROXY_PASSWORD);
        settings.insert(
            keys::OPTION_CUSTOM_RENDEZVOUS_SERVER.to_owned(),
            ID_SERVER.to_owned(),
        );
        settings.insert(
            keys::OPTION_RELAY_SERVER.to_owned(),
            RELAY_SERVER.to_owned(),
        );
        settings.insert(keys::OPTION_API_SERVER.to_owned(), API_SERVER.to_owned());
        settings.insert(keys::OPTION_KEY.to_owned(), SERVER_KEY.to_owned());
    }

    {
        let mut settings = config::BUILTIN_SETTINGS.write().unwrap();
        settings.insert(keys::OPTION_HIDE_SERVER_SETTINGS.to_owned(), "Y".to_owned());
        settings.insert(keys::OPTION_HIDE_PROXY_SETTINGS.to_owned(), "Y".to_owned());
        settings.insert(
            keys::OPTION_HIDE_WEBSOCKET_SETTINGS.to_owned(),
            "Y".to_owned(),
        );
    }

    {
        let mut settings = config::DEFAULT_SETTINGS.write().unwrap();
        settings.remove(keys::OPTION_PROXY_URL);
        settings.remove(keys::OPTION_PROXY_USERNAME);
        settings.remove(keys::OPTION_PROXY_PASSWORD);
    }

    Config::set_socks(None);
}

pub fn proxy_locked() -> bool {
    config::BUILTIN_SETTINGS
        .read()
        .unwrap()
        .get(keys::OPTION_HIDE_PROXY_SETTINGS)
        .map_or(false, |value| value == "Y")
}
