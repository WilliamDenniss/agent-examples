import os
import sys
import time
from datetime import datetime, timedelta
from typing import List, Dict, Any, Optional
from dotenv import load_dotenv

from alpaca.data.historical import NewsClient, StockHistoricalDataClient
from alpaca.data.requests import NewsRequest, StockLatestQuoteRequest
from alpaca.trading.client import TradingClient
from alpaca.trading.requests import MarketOrderRequest
from alpaca.trading.enums import OrderSide, TimeInForce

from google.adk.agents import Agent
from google.adk.agents.callback_context import CallbackContext
from vertexai import agent_engines

# Load environment variables
env_path = os.path.join(os.path.dirname(__file__), '.env')
load_dotenv(env_path)

# API Keys
APCA_API_KEY_ID = os.getenv('APCA_API_KEY_ID')
APCA_API_SECRET_KEY = os.getenv('APCA_API_SECRET_KEY')

if not APCA_API_KEY_ID:
    sys.exit("Error: APCA_API_KEY_ID environment variable is not set. Did you create your `trading_agent/.env` file?")

# Initialize Alpaca Clients
trading_client = TradingClient(APCA_API_KEY_ID, APCA_API_SECRET_KEY, paper=True)
news_client = NewsClient(APCA_API_KEY_ID, APCA_API_SECRET_KEY)
stock_client = StockHistoricalDataClient(APCA_API_KEY_ID, APCA_API_SECRET_KEY)

# Full S&P 500 Tickers List (Retrieved April 2026)
SP500_TICKERS = [
"A", "AAPL", "ABBV", "ABT", "ACGL", "ACN", "ADBE", "ADI", "ADM", "ADP", "ADSK", "AEE", "AEP", "AES", "AFL", "AIG", "AIZ", "AJG", "AKAM", "ALB", "ALGN", "ALL", "ALLE", "AMAT", "AMCR", "AMD", "AME", "AMGN", "AMP", "AMT", "AMZN", "ANET", "AON", "AOS", "APA", "APD", "APH", "APO", "APP", "APTV", "ARE", "ATO", "AVB", "AVGO", "AVY", "AWK", "AXON", "AXP", "AZO", "BA", "BAC", "BALL", "BAX", "BBY", "BDX", "BEN", "BF.B", "BG", "BIIB", "BK", "BKNG", "BKR", "BLDR", "BLK", "BMY", "BR", "BRO", "BRK.B", "BSX", "BWA", "BX", "BXP", "C", "CAG", "CAH", "CARR", "CAT", "CB", "CBOE", "CBRE", "CCI", "CCL", "CDNS", "CDW", "CEG", "CF", "CFG", "CHD", "CHRW", "CHTR", "CI", "CINF", "CL", "CLX", "CMA", "CMCSA", "CME", "CMG", "CMI", "CMS", "CNC", "CNP", "COF", "COO", "COP", "COR", "COST", "CPAY", "CPB", "CPRT", "CPT", "CRL", "CRM", "CRWD", "CSCO", "CSGP", "CSX", "CTAS", "CTSH", "CTVA", "CVS", "CVX", "CZR", "D", "DAL", "DAY", "DD", "DE", "DECK", "DELL", "DFS", "DG", "DGX", "DHI", "DHR", "DIS", "DLR", "DLTR", "DOC", "DOV", "DOW", "DPZ", "DRI", "DTE", "DUK", "DVA", "DVN", "DXCM", "EA", "EBAY", "ECL", "ED", "EFX", "EG", "EIX", "EL", "ELV", "EMN", "EMR", "ENPH", "EOG", "EPAM", "EQT", "EQR", "ERIE", "ES", "ESS", "ETN", "ETR", "EVRG", "EW", "EXC", "EXPD", "EXPE", "EXR", "F", "FANG", "FAST", "FCX", "FDS", "FDX", "FE", "FFIV", "FI", "FICO", "FIS", "FITB", "FMC", "FOX", "FOXA", "FRT", "FSLR", "FTNT", "FTV", "GD", "GDDY", "GE", "GEHC", "GEN", "GEV", "GILD", "GIS", "GL", "GLW", "GM", "GNRC", "GOOG", "GOOGL", "GPC", "GPN", "GRMN", "GS", "GWW", "HAL", "HAS", "HBAN", "HCA", "HD", "HES", "HIG", "HII", "HLT", "HOLX", "HON", "HPE", "HPQ", "HRL", "HSIC", "HST", "HSY", "HUBB", "HUM", "HWM", "IBM", "ICE", "IDXX", "IEX", "IFF", "ILMN", "INCY", "INTC", "INTU", "INVH", "IP", "IPG", "IQV", "IR", "IRM", "ISRG", "IT", "ITW", "IVZ", "J", "JBHT", "JCI", "JKHY", "JNJ", "JPM", "K", "KDP", "KEY", "KEYS", "KHC", "KIM", "KLAC", "KMB", "KMI", "KMX", "KO", "KR", "KVUE", "L", "LDOS", "LEN", "LH", "LHX", "LII", "LIN", "LKQ", "LLY", "LMT", "LNT", "LOW", "LRCX", "LULU", "LUV", "LVS", "LW", "LYB", "LYV", "MA", "MAA", "MAR", "MAS", "MCD", "MCHP", "MCK", "MCO", "MDLZ", "MDT", "MET", "META", "MGM", "MHK", "MKC", "MLM", "MMC", "MMM", "MNST", "MO", "MOH", "MOS", "MPC", "MPWR", "MRK", "MRNA", "MS", "MSCI", "MSFT", "MSI", "MTB", "MTD", "MU", "NDAQ", "NDSN", "NEE", "NEM", "NFLX", "NI", "NKE", "NOC", "NOW", "NRG", "NSC", "NTAP", "NTRS", "NUE", "NVDA", "NVR", "NWS", "NWSA", "NXPI", "O", "ODFL", "OKE", "OMC", "ON", "ORCL", "ORLY", "OTIS", "OXY", "PANW", "PARA", "PAYC", "PAYX", "PCAR", "PCG", "PEAK", "PEG", "PEP", "PFE", "PFG", "PG", "PGR", "PH", "PHM", "PKG", "PLD", "PLTR", "PM", "PNC", "PNR", "PNW", "PODD", "POOL", "PPG", "PPL", "PRU", "PSA", "PSX", "PTC", "PWR", "PYPL", "QCOM", "QRVO", "RCL", "REG", "REGN", "RF", "RHI", "RJF", "RL", "RMD", "ROK", "ROL", "ROP", "ROST", "RSG", "RTX", "RVTY", "SBAC", "SBUX", "SCHW", "SHW", "SJM", "SLB", "SMCI", "SNA", "SNPS", "SO", "SOLV", "SPG", "SPGI", "SRE", "STE", "STLD", "STT", "STX", "STZ", "SWK", "SWKS", "SYF", "SYK", "SYY", "T", "TAP", "TDG", "TDY", "TECH", "TEL", "TER", "TFC", "TFX", "TGT", "TJX", "TKO", "TMUS", "TMO", "TPR", "TRGP", "TRMB", "TROW", "TRV", "TSCO", "TSLA", "TSN", "TT", "TTWO", "TXN", "TXT", "TYL", "UAL", "UBER", "UDR", "UHS", "ULTA", "UNH", "UNP", "UPS", "URI", "USB", "V", "VFC", "VICI", "VLO", "VLTO", "VMC", "VRSK", "VRSN", "VRTX", "VST", "VTR", "VTRS", "VZ", "WAB", "WAT", "WBA", "WBD", "WDC", "WEC", "WELL", "WFC", "WHR", "WM", "WMB", "WMT", "WRB", "WST", "WTW", "WY", "WYNN", "XEL", "XOM", "XYL", "YUM", "ZBH", "ZBRA", "ZION", "ZTS"
]

def get_financial_news() -> str:
    """
    Fetches the latest financial news for ALL S&P 500 companies from the last 24 hours.
    Splits into two batches to stay within URL length limits.
    """
    start_time = datetime.now() - timedelta(days=1)
    
    # Split tickers into two batches of approx 250 each
    mid = len(SP500_TICKERS) // 2
    batches = [SP500_TICKERS[:mid], SP500_TICKERS[mid:]]
    
    all_formatted_news = []
    
    for batch in batches:
        request_params = NewsRequest(
            symbols=",".join(batch),
            start=start_time,
            limit=50
        )
        time.sleep(1)  # Rate-limit delay
        try:
            news_response = news_client.get_news(request_params)
            for article in news_response.data['news']:
                # Focus on news stories specific to 1-3 symbols
                if 1 <= len(article.symbols) <= 3:
                    symbols_str = ", ".join(article.symbols)
                    all_formatted_news.append(
                        f"Ticker(s): {symbols_str}\n"
                        f"Headline: {article.headline}\n"
                        f"Summary: {article.summary}\n"
                        "---"
                    )
        except Exception as e:
            print(f"Error fetching news for batch: {str(e)}")

    if not all_formatted_news:
        return "No relevant single-stock news found for the S&P 500 in the last 24 hours."
        
    return "\n".join(all_formatted_news)

def get_portfolio_status() -> Dict[str, Any]:
    """Queries Alpaca for account status and open positions."""
    time.sleep(1)
    account = trading_client.get_account()
    time.sleep(1)
    positions = trading_client.get_all_positions()
    
    pos_list = []
    for p in positions:
        pos_list.append({
            "symbol": p.symbol,
            "qty": float(p.qty),
            "market_value": float(p.market_value),
            "current_price": float(p.current_price)
        })
        
    return {
        "available_cash": float(account.cash),
        "positions": pos_list
    }

def get_latest_price(symbol: str) -> float:
    """Retrieves the most recent ask price for a specific ticker."""
    request_params = StockLatestQuoteRequest(symbol_or_symbols=symbol)
    time.sleep(1)
    quote = stock_client.get_stock_latest_quote(request_params)
    return float(quote[symbol].ask_price)

def place_trade_order(symbol: str, side: str, amount_usd: Optional[float] = None, qty: Optional[float] = None) -> str:
    """Places a market order (fractional shares supported for buys)."""
    side = side.lower()
    if side not in ['buy', 'sell']:
        return "Error: Side must be 'buy' or 'sell'."

    order_side = OrderSide.BUY if side == 'buy' else OrderSide.SELL
    
    try:
        if amount_usd is not None and side == 'buy':
            order_request = MarketOrderRequest(
                symbol=symbol,
                notional=amount_usd,
                side=order_side,
                time_in_force=TimeInForce.DAY
            )
        elif qty is not None:
            order_request = MarketOrderRequest(
                symbol=symbol,
                qty=qty,
                side=order_side,
                time_in_force=TimeInForce.GTC
            )
        else:
            return "Error: Either amount_usd (for buy) or qty (for sell/buy) must be provided."

        time.sleep(1)
        order = trading_client.submit_order(order_data=order_request)
        return f"Success: {side.upper()} order placed for {symbol}. Order ID: {order.id}"
    except Exception as e:
        return f"Failed to place {side} order for {symbol}: {str(e)}"

# Define the Agent
root_agent = Agent(
    name="TradingAgent",
    model="gemini-2.5-pro",
    instruction="""
    You are a sophisticated stock trading AI agent using Gemini 2.5 Pro. Your mission is to execute a daily trading cycle based on news sentiment for the entire S&P 500.
    
    FOLLOW THESE STEPS IN ORDER:
    
    1. NEWS LOOKUP: Call `get_financial_news()` to discover the latest news affecting any of the 500 S&P companies.
    
    2. SENTIMENT ANALYSIS: 
       - Analyze the news for positive or negative sentiments using Gemini 2.5 Pro and assign a sentiment rating between -1.0 and 1.0.
       - CRITICAL: Ignore Stock Analyst Rating changes; market news only.
       - CRITICAL: Only consider news stories specific to 1-3 stocks.
       - Format your tracking of each analyzed story as: Primary ticker affected, news summary, score.
    
    3. PORTFOLIO QUERY: Call `get_portfolio_status()`.
    
    4. SELL PHASE:
       - For every stock held: If sentiment score is NEGATIVE (< 0), sell ALL shares.
       - If no negative sentiment, do not sell.
    
    5. BUY PHASE:
       - Identify stocks NOT held that have **high confidence positive sentiments**.
       - Rank by positivity.
       - Create market BUY trades for EXACTLY $1000 of EACH of **up to 5** stocks with highest scores.
       - Stop if available cash is less than $1000.
    
    6. FINAL REPORT:
       Produce a comprehensive summary:
       - SUMMARY OF ORDERS: List all orders placed with ticker, action, score, and news summary.
       - MARKET SENTIMENT OVERVIEW: Top 10 Positive and Top 10 Negative news stories (Ticker, Summary, and Score).
    
    You have access to memories from past trading sessions. Use them to inform your decisions — for example, if you previously traded a stock based on similar news, consider the outcome.

    Execute the entire cycle once when prompted.
    """,
    tools=[get_financial_news, get_portfolio_status, get_latest_price, place_trade_order]
)

# Wrap in AdkApp for execution
app = agent_engines.AdkApp(agent=root_agent)


