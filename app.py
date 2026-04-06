import streamlit as st
from agent import chat_turn, get_system_prompt

st.set_page_config(page_title="PackMate AI", page_icon="🧳", layout="wide")

# UI Styling & Header
st.title("🧳 PackMate - Travel Agent")
st.markdown("*Your AI Assistant for intelligent packing based on real-time weather.*")
st.info("Language: Adaptive (Speak to me in your language) | Interface: English")

# Initialize Session
if "llm_messages" not in st.session_state:
    st.session_state.llm_messages = [get_system_prompt()]
if "chat_messages" not in st.session_state:
    st.session_state.chat_messages = []

# Sidebar Controls
with st.sidebar:
    st.header("Actions")
    if st.button("🔄 Reset Conversation", use_container_width=True):
        st.session_state.llm_messages = [get_system_prompt()]
        st.session_state.chat_messages = []
        st.rerun()
    st.divider()
    st.write("**Architecture:** GitOps / OpenShift AI")

# Display Chat History
for msg in st.session_state.chat_messages:
    with st.chat_message(msg["role"]):
        st.markdown(msg["content"])

# User Input
if prompt := st.chat_input("Ex: Je vais à Paris demain"):
    st.chat_message("user").write(prompt)
    st.session_state.chat_messages.append({"role": "user", "content": prompt})
    st.session_state.llm_messages.append({"role": "user", "content": prompt})

    with st.chat_message("assistant"):
        with st.spinner("Analyzing weather and preparing your kit..."):
            response = chat_turn(st.session_state.llm_messages)
            st.markdown(response)
            st.session_state.chat_messages.append({"role": "assistant", "content": response})