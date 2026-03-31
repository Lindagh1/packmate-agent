import streamlit as st
from agent import chat_turn, get_system_prompt

st.set_page_config(page_title="PackMate", page_icon="🧳", layout="centered")

st.title("🧳 PackMate - Assistant Voyage")
st.caption("Dis-moi où tu pars, je vérifie la météo et on prépare ta valise !")

# Initialisation de la mémoire
if "llm_messages" not in st.session_state:
    st.session_state.llm_messages = [get_system_prompt()]
    st.session_state.chat_messages = []
if "chat_messages" not in st.session_state:
    st.session_state.chat_messages = []


# Affichage des anciens messages
for msg in st.session_state.chat_messages:
    st.chat_message(msg["role"]).write(msg["content"])

# Zone de discussion
if prompt := st.chat_input("Ex: Je pars à Rome le week-end prochain"):
    
    st.chat_message("user").write(prompt)
    
    # On ajoute la question de l'utilisateur dans les historiques
    st.session_state.chat_messages.append({"role": "user", "content": prompt})
    st.session_state.llm_messages.append({"role": "user", "content": prompt})

    # On lance l'agent
    with st.chat_message("assistant"):
        with st.spinner("Je vérifie la météo et je prépare ta liste..."):
            response = chat_turn(st.session_state.llm_messages)
            st.markdown(response)
    
    # On sauvegarde la réponse de l'agent
    st.session_state.chat_messages.append({"role": "assistant", "content": response})

# Bouton de remise à zéro dans le menu de gauche
with st.sidebar:
    st.header("Options")
    if st.button("🔄 Nouvelle conversation"):
        st.session_state.llm_messages = [get_system_prompt()]
        st.session_state.chat_messages = []
        st.rerun()