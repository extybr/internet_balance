import time
from playwright.sync_api import sync_playwright
from secret import *

def rt_balance(login, password):
    """
    Быстрое получение баланса Ростелеком
    """
    with sync_playwright() as p:
        # Запускаем браузер в фоне
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        
        try:
            # Переходим на сайт
            page.goto("https://lk.rt.ru")
            
            # Ждем и кликаем "Войти с паролем"
            page.wait_for_selector("#standard_auth_btn", timeout=10000)
            page.click("#standard_auth_btn")
            
            # Небольшая пауза для появления опций
            time.sleep(1)
            
            # Выбираем "Логин"
            page.wait_for_selector("#t-btn-tab-login", timeout=10000)
            page.click("#t-btn-tab-login")
            
            # Пауза для активации полей
            time.sleep(0.5)
            
            # Вводим логин и пароль
            page.fill("#username", login)
            page.fill("#password", password)
            
            # Нажимаем кнопку входа
            page.click("button:has-text('Войти')")
            
            # Ждем появления элемента с балансом (увеличенный таймаут)
            page.wait_for_selector(".main-page_control_account_balance h2", timeout=30000)
            
            # Дополнительная пауза для гарантии загрузки
            time.sleep(1)
            
            # Получаем баланс
            balance = page.locator(".main-page_control_account_balance h2").first.text_content()
            
            balance = balance.strip() if balance else "Баланс не найден"
            
            user_element = page.locator(".app-header_profile_header_user").first.text_content()
            
            user_element = user_element.strip() if user_element else "Лицевой счет не найден"
            
            print(f"🏠 Лицевой счет: {user_element}")
            print(f"💰 Текущий баланс: {balance}")
            
        except Exception as e:
            return f"Ошибка: {str(e)}"
        finally:
            browser.close()

# Использование
if __name__ == "__main__":
    LOGIN = RT_USERNAME             # Ваш лицевой счет
    PASSWORD = RT_PASSWORD          # Ваш пароль
    
    rt_balance(LOGIN, PASSWORD)
    
