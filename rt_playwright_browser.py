import time
import re
from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeoutError
from secret import *

def login_rt(username: str, password: str):
    """
    Авторизация в личном кабинете Ростелеком (lk.rt.ru)
    """
    with sync_playwright() as p:
        # Запускаем браузер
        browser = p.chromium.launch(
            headless=False, 
            slow_mo=200
        )
        context = browser.new_context(viewport={'width': 1280, 'height': 800})
        page = context.new_page()

        try:
            print("🔄 Выполняется вход в личный кабинет...")
            page.goto("https://lk.rt.ru", wait_until="networkidle")

            # Шаг 1: Кнопка "Войти с паролем"
            standard_auth_btn = page.locator("#standard_auth_btn")
            standard_auth_btn.wait_for(state="visible", timeout=10000)
            standard_auth_btn.click()

            # Шаг 2: Выбираем опцию "Логин"
            login_option = page.locator("#t-btn-tab-login")
            login_option.wait_for(state="visible", timeout=10000)
            login_option.click()
            page.wait_for_timeout(500)

            # Шаг 3: Заполняем логин и пароль
            username_field = page.locator("#username")
            username_field.wait_for(state="visible", timeout=5000)
            username_field.fill(username)

            password_field = page.locator("#password")
            password_field.wait_for(state="visible", timeout=5000)
            password_field.fill(password)

            # Шаг 4: Нажимаем кнопку входа
            submit_btn = page.locator(
                "#t-btn-login, button:has-text('Войти'), button[type='submit']"
            ).first
            submit_btn.click()

            # Шаг 5: Проверяем успешный вход и собираем информацию
            user_selector = ".app-header_profile_header_user"
            page.wait_for_selector(user_selector, timeout=30000)
            
            # Даем время подгрузиться данным
            page.wait_for_timeout(2000)
            
            # Собираем информацию о кабинете
            print("\n" + "="*50)
            print("✅ ВЫ УСПЕШНО ВОШЛИ В КАБИНЕТ")
            print("="*50)
            
            # Лицевой счет
            user_element = page.locator(".app-header_profile_header_user").first
            if user_element.count() > 0:
                account_number = user_element.text_content()
                print(f"🏠 Лицевой счет: {account_number}")
            
            # Баланс
            balance_element = page.locator(".main-page_control_account_balance h2").first
            if balance_element.count() > 0:
                balance = balance_element.text_content()
                print(f"💰 Баланс: {balance}")
            else:
                # Альтернативный поиск баланса
                balance_alt = page.locator("[class*='balance'] h2").first
                if balance_alt.count() > 0:
                    balance = balance_alt.text_content()
                    print(f"💰 Баланс: {balance}")
            
            print("="*50)
            
            # Сохраняем скриншот
            timestamp = time.strftime("%Y%m%d_%H%M%S")
            screenshot_name = f"cabinet_{timestamp}.png"
            page.screenshot(path=screenshot_name)
            print(f"📸 Скриншот сохранен: {screenshot_name}")
            
            print("\n⏱️ Кабинет будет открыт 15 секунд для просмотра...")
            time.sleep(15)
            
            return True

        except PlaywrightTimeoutError as e:
            print(f"❌ Ошибка входа: {e}")
            page.screenshot(path="login_error.png", full_page=True)
            return False
        except Exception as e:
            print(f"❌ Ошибка: {e}")
            return False
        finally:
            print("\n🔄 Закрытие браузера...")
            browser.close()

if __name__ == "__main__":
    # ЗАМЕНИТЕ НА СВОИ ДАННЫЕ
    LOGIN = RT_USERNAME             # Ваш лицевой счет
    PASSWORD = RT_PASSWORD          # Ваш пароль
    
    login_rt(USERNAME, PASSWORD)
